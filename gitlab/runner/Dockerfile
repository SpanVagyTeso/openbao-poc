FROM gitlab/gitlab-runner:ubuntu-v19.4.1

# curl, ssh and ssh-keygen are already included; jobs also need jq to talk to the OpenBao API
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq \
 && rm -rf /var/lib/apt/lists/*
