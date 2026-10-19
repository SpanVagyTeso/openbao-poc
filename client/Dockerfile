FROM oraclelinux:9

RUN dnf -y install openssh-clients jq \
 && dnf clean all

COPY connect.sh /usr/local/bin/connect.sh
RUN chmod 0755 /usr/local/bin/connect.sh

ENTRYPOINT ["/usr/local/bin/connect.sh"]
CMD ["id && uname -n && echo 'Logged in with an OpenBao-signed certificate'"]
