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
| SSH target    | `ssh -p 2222 demo@localhost`             | `ssh-target:22`            | SSH certificate signed by OpenBao (see below)        |
| GitLab        | http://localhost:8929                    | `http://gitlab:8929`       | User `root`, password in `secrets/gitlab/root-password` |
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
- **Configured by OpenTofu (`tofu/`):** SSH CA mount `ssh-client-signer`, role `demo`, policy `ssh-sign-demo`.

## SSH target

Oracle Linux sshd that only accepts certificates signed by the OpenBao CA. There is no password login.

- **Address:** `localhost:2222`, user `demo`
- **Connect from Windows:** `.\connect.ps1`. It generates a key, has OpenBao sign it, and logs in.

  ```powershell
  .\connect.ps1                       # interactive shell
  .\connect.ps1 -Ttl 15m              # longer certificate lifetime (max 30m)
  .\connect.ps1 -Command 'id'         # run a single command
  .\connect.ps1 -ResetHostKey         # after ssh-target was recreated
  ```

- **Connect from a container:** `docker compose run --rm ssh-client`
- **Logs:** `docker compose logs -f ssh-target` (sshd logs, including the certificate key ID and serial)

## GitLab

- **Web UI:** http://localhost:8929, user `root`, password in `secrets/gitlab/root-password`
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
