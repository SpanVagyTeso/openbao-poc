# Services

Where to reach each service of the compose stack, and the credentials to log in.

Start everything with `docker compose up -d`, or only one part:

```sh
docker compose up -d ssh-target      # OpenBao + OpenTofu + SSH target
docker compose up -d gitlab-runner   # GitLab + OpenTofu + runner
```

All credentials are generated on first start into `secrets/` (git-ignored).

## Overview

| Service       | From your machine                        | Inside the compose network | Credentials                                          |
|---------------|------------------------------------------|----------------------------|------------------------------------------------------|
| OpenBao       | http://localhost:8200 (UI: `/ui`)        | `http://openbao:8200`      | Root token: `root_token` in `secrets/init.json`      |
| SSH target    | `localhost:2222` (`fodor.kristof`, `other-user`) | `ssh-target:22`            | SSH certificate signed by OpenBao (see below)        |
| GitLab        | http://localhost:8929                    | `http://gitlab:8929`       | User `root`, password in `secrets/gitlab/root-password`; demo users below |
| GitLab Runner | no port, check in GitLab                 | -                          | Registered automatically by `gitlab-tofu`            |

One-shot services (`openbao-keygen`, `openbao-init`, `tofu`, `gitlab-keygen`, `gitlab-tofu`) exit after
they finish and have no endpoint. Their output is in `docker compose logs <service>`.

## OpenBao

- **UI:** http://localhost:8200/ui, sign in with method *Token*, using the root token.
- **API / CLI:** `http://localhost:8200`

  ```powershell
  $env:BAO_ADDR  = 'http://localhost:8200'
  $env:BAO_TOKEN = (Get-Content secrets\init.json -Raw | ConvertFrom-Json).root_token
  bao status
  ```

- **Files in `secrets/`:**
  - `init.json`: root token and recovery key
  - `unseal/unseal.key`: static auto-unseal key, keep it safe
- **Configured by OpenTofu (`tofu/`):** SSH CA mount `ssh-client-signer` and JWT auth method `jwt`, plus for
  each user in `ssh_users` (`tofu/variables.tf`), all named after the user:

  | What                | `fodor.kristof`                       | `other-user`                       |
  |---------------------|---------------------------------------|------------------------------------|
  | SSH role            | `ssh-client-signer/roles/fodor.kristof` | `ssh-client-signer/roles/other-user` |
  | Policy              | `ssh-sign-fodor.kristof`              | `ssh-sign-other-user`              |
  | JWT role (GitLab CI) | `auth/jwt/role/fodor.kristof`        | `auth/jwt/role/other-user`         |

  Each SSH role only signs certificates for its own user, and each policy only allows its own SSH role.
  See [SSH certificates from GitLab CI](#ssh-certificates-from-gitlab-ci).

## SSH target

Oracle Linux sshd that only accepts certificates signed by the OpenBao CA. There is no password login.

- **Address:** `localhost:2222`
- **Users:** `fodor.kristof` and `other-user`. A certificate only works for the user it was issued to:
  OpenBao only puts that user in it, and sshd requires the certificate's principal to match the login name.
- **Connect from Windows:** `.\connect.ps1`. It generates a key, has OpenBao sign it with the root token,
  and logs in.

  ```powershell
  .\connect.ps1                       # interactive shell as fodor.kristof
  .\connect.ps1 -User other-user      # as other-user
  .\connect.ps1 -Ttl 15m              # longer certificate lifetime (max 30m)
  .\connect.ps1 -Command 'id'         # run a single command
  .\connect.ps1 -ResetHostKey         # after ssh-target was recreated
  ```

- **Logs:** `docker compose logs -f ssh-target` (sshd logs, including the certificate key ID and serial)

## GitLab

- **Web UI:** http://localhost:8929, user `root`, password in `secrets/gitlab/root-password`
- **Demo users:** all are Maintainers of `root/hello-world`, so GitLab treats them the same.
  Only OpenBao tells them apart.

  | Username        | Email                       | Password   | SSH certificate from OpenBao             |
  |-----------------|-----------------------------|------------|------------------------------------------|
  | `fodor.kristof` | fodor.kristof@microsec.hu   | `almaalma` | only for `fodor.kristof` on ssh-target   |
  | `other-user`    | other-user@microsec.hu      | `almaalma` | only for `other-user` on ssh-target      |
  | `unknown`       | unknown@microsec.hu         | `almaalma` | none, OpenBao rejects the login          |

  You can sign in with the username or the email. GitLab refuses passwords shorter than 8 characters at
  login, so `alma` can't be used. `gitlab/seed.rb` sets the password directly in Rails, because the API
  would reject it as too weak.
- **API:** `http://localhost:8929/api/v4`, with the root token from `secrets/gitlab/root-token`

  ```powershell
  $token = Get-Content secrets\gitlab\root-token
  Invoke-RestMethod -Headers @{ 'PRIVATE-TOKEN' = $token } http://localhost:8929/api/v4/projects
  ```

- **Clone over HTTP:** `git clone http://localhost:8929/root/hello-world.git`, logging in as `root`.
  Git over SSH is disabled.
- **Hello world project:** http://localhost:8929/root/hello-world/-/pipelines
- **First start** takes about 3–5 minutes. Check progress with `docker compose ps gitlab` (wait for `healthy`).

## GitLab Runner

The runner has no port of its own. It connects to GitLab at `http://gitlab:8929` and runs jobs with the shell
executor inside its container.

- **Status:** http://localhost:8929/admin/runners (look for *compose shell runner*, which should be online)
- **Logs:** `docker compose logs -f gitlab-runner`

## SSH certificates from GitLab CI

The `ssh-certificate` job in `root/hello-world` shows the whole flow:

1. GitLab issues the job an `id_token` (`OPENBAO_ID_TOKEN`) with `aud: openbao`. It is a JWT signed by GitLab
   that includes, among other claims, the login and email of the user who started the pipeline
   (`user_login`, `user_email`).
2. The job logs in to OpenBao at `http://openbao:8200/v1/auth/jwt/login` with the JWT role named after that
   user (`$GITLAB_USER_LOGIN`). OpenBao checks the signature against GitLab's keys
   (`http://gitlab:8929/oauth/discovery/keys`), the issuer `http://localhost:8929`, the audience `openbao`, and
   that `user_login` and `user_email` belong to that role. Picking someone else's role doesn't help, because
   the claims in the token wouldn't match.
3. If the login succeeds, OpenBao returns a token with only that user's policy (e.g. `ssh-sign-other-user`).
   The job uses it to sign a fresh SSH key with the user's own SSH role and logs in to `ssh-target` as that user.
   Signing with another user's role is denied (403), and so is asking for another login in the certificate.
4. For a user without a role (`unknown`), the login fails with `role "unknown" could not be found` and the
   job fails.

The first pipeline is committed as `fodor.kristof`, so it logs in as `fodor.kristof`. To try the others, sign in
as `other-user` or `unknown`, open http://localhost:8929/root/hello-world/-/pipelines/new and run a pipeline on
`main`.

To add a user, add them to `ssh_users` in `tofu/variables.tf`, `ssh-target/Dockerfile` and `gitlab/seed.rb`.
