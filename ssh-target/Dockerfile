FROM oraclelinux:9

RUN dnf -y install openssh-server rsyslog \
 && dnf clean all \
 # pam_loginuid cannot write /proc/self/loginuid inside a container
 && sed -i 's/^session\s\+required\s\+pam_loginuid.so/session optional pam_loginuid.so/' /etc/pam.d/sshd \
 # Users have no password and no authorized_keys - only CA-signed certificates get in.
 # sshd only accepts a certificate whose principal matches the login name.
 && for user in fodor.kristof other-user; do useradd -m "$user" && usermod -p '*' "$user"; done

COPY rsyslog.conf /etc/rsyslog.conf
COPY 10-openbao-ca.conf /etc/ssh/sshd_config.d/10-openbao-ca.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh && chmod 0600 /etc/ssh/sshd_config.d/10-openbao-ca.conf

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
