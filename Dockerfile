FROM centos:6.7
MAINTAINER Raymond Barbiero "raymond.barbiero.dev@gmail.com"

RUN true \
 && yum -y update \
 && yum -y install wget rsyslog cronie python-argparse \
 && ln -sf /usr/share/zoneinfo/UTC /etc/localtime

RUN true \
 && GOSU_VERSION=1.4 \
 && wget -q -L "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64" -O /bin/gosu \
 && chmod +x /bin/gosu

ADD sudo-wrapper /usr/bin/sudo
RUN chmod +x /usr/bin/sudo

# set mta to use ssmtp
RUN true \
 && yum -y install http://dl.fedoraproject.org/pub/epel/6/x86_64/ssmtp-2.61-22.el6.x86_64.rpm \
 && alternatives --config mta <<< '1' \
 && echo 2 \
 && sed -i'' -e 's/mailhub=.*/smtp.gmail.com:587/g' /etc/ssmtp/ssmtp.conf \
    -e 's/#UseSTARTTLS\s*=.*/UseSTARTTLS=yes/g' /etc/ssmtp/ssmtp.conf \
    -e 's/#UseTLS\s*=.*/UseTLS=yes/g' /etc/ssmtp/ssmtp.conf \
    -e 's/#AuthUser\s*=.*/AuthUser=myemail@gmail.com/g' /etc/ssmtp/ssmtp.conf \
    -e 's/#AuthPass\s*=.*/AuthPass=mypassword/g' /etc/ssmtp/ssmtp.conf \
 && true

# setup runit
ADD ./runit-2.1.2-1.el6.x86_64.rpm /
RUN yum -y install /runit-2.1.2-1.el6.x86_64.rpm \
 && rm /runit-2.1.2-1.el6.x86_64.rpm

ADD my_init /sbin/my_init
RUN chmod +x /sbin/my_init
RUN mkdir -p /etc/runit \
 && mkdir -p /etc/service \
 && mkdir -p /etc/my_init.d \
 && mkdir -p /etc/container_environment \
 && touch /etc/container_environment.sh \
 && touch /etc/container_environment.json \
 && chmod 700 /etc/container_environment \
 && chmod 640 /etc/container_environment.sh \
              /etc/container_environment.json \
 && ln -s /etc/container_environment.sh /etc/profile.d/

RUN echo -n no > /etc/container_environment/INITRD \
 && echo -n en_US.UTF-8 > /etc/container_environment/LANG \
 && echo -n en_US.UTF-8 > /etc/container_environment/LC_CTYPE 

RUN echo '#!/usr/bin/env bash'     > /etc/runit/1 \
 && echo 'logger Starting runit 1' >> /etc/runit/1 \
 && echo 'echo Welcome to baseimage > /dev/console' >> /etc/runit/1 \
 && chmod 755 /etc/runit/1 \
 && echo '#!/usr/bin/env bash' > /etc/runit/2 \
 && echo 'echo Running services in /etc/service' >> /etc/runit/2 \
 && echo 'runsvdir -P /etc/service' >> /etc/runit/2 \
 && chmod 755 /etc/runit/2 \
 && echo '#!/usr/bin/env bash' > /etc/runit/3 \
 && echo 'echo Goodbye!' >> /etc/runit/3 \
 && chmod 755 /etc/runit/3

RUN mkdir -p /etc/service/rsyslogd \
 && echo '#!/usr/bin/env bash' > /etc/service/rsyslogd/run \
 && echo 'set -e' >> /etc/service/rsyslogd/run \
 && echo '. /etc/sysconfig/rsyslog' >> /etc/service/rsyslogd/run \
 && echo 'exec /sbin/rsyslogd -n $SYSLOGD_OPTIONS' >> /etc/service/rsyslogd/run \
 && chmod 755 /etc/service/rsyslogd/run \
 && sed -i'' -e 's/^\$ModLoad imklog/#\$ModLoad imklog/g' /etc/rsyslog.conf

RUN mkdir -p /etc/service/crond \
 && echo '#!/usr/bin/env bash' > /etc/service/crond/run \
 && echo 'sv check /etc/service/rsyslogd >/dev/null || exit 1' >> /etc/service/crond/run \
 && echo 'exec /usr/sbin/crond -n 1>&2' >> /etc/service/crond/run \
 && chmod 755 /etc/service/crond/run \
 && chmod 600 /etc/crontab

RUN mkdir -p /etc/service/sshd \
 && mkdir -p /etc/my_init.d \
 && yum -y install openssh-server \
 && touch /etc/service/sshd/down \
 && echo '#!/usr/bin/env bash' > /etc/service/sshd/run \
 && echo 'set -e' >> /etc/service/sshd/run \
 && echo 'exec /usr/sbin/sshd -D' >> /etc/service/sshd/run \
 && chmod +x /etc/service/sshd/run \
 && echo '#!/usr/bin/env bash' > /etc/my_init.d/00_regen_ssh_host_keys.sh \
 && echo 'set -e' >> /etc/my_init.d/00_regen_ssh_host_keys.sh \
 && echo 'if [[ ! -e /etc/service/sshd/down && ! -e /etc/ssh/ssh_host_rsa_key ]] || [[ "$1" == "-f" ]]; then' >> /etc/my_init.d/00_regen_ssh_host_keys.sh \
 && echo '  echo "No SSH host key available. Generating one..."'  >> /etc/my_init.d/00_regen_ssh_host_keys.sh \
 && echo '  openssl genrsa -out /etc/ssh/ssh_host_rsa_key 4096' >> /etc/my_init.d/00_regen_ssh_host_keys.sh \
 && echo '  openssl rsa -pubout -in /etc/ssh/ssh_host_rsa_key -out /etc/ssh/ssh_host_rsa_key.pub'  >> /etc/my_init.d/00_regen_ssh_host_keys.sh \
 && echo '  chmod 600 /etc/ssh/ssh_host_rsa_key'  >> /etc/my_init.d/00_regen_ssh_host_keys.sh \
 && echo 'fi' >> /etc/my_init.d/00_regen_ssh_host_keys.sh \
 && chmod +x /etc/my_init.d/00_regen_ssh_host_keys.sh \
 && mkdir -p /root/.ssh \
 && chmod 700 /root/.ssh \
 && chown root:root /root/.ssh \
 && sed -i'' -e 's@PasswordAuthentication yes@#PasswordAuthentication yes@g' \
    -e 's@GSSAPIAuthentication yes@#GSSAPIAuthentication yes@g' \
    -e 's@GSSAPICleanupCredentials yes@#GSSAPICleanupCredentials yes@g' \
    -e 's@UsePAM yes@#UsePAM yes@g' \
    -e 's@AcceptEnv@#AcceptEnv@g' \
    -e 's@#HostKey\s*/etc/ssh/ssh_host_rsa_key@HostKey /etc/ssh/ssh_host_rsa_key@g' \
    -e 's@X11Forwarding yes@#X11Forwarding yes@g' /etc/ssh/sshd_config \
 && echo 'UseDNS no' >> /etc/ssh/sshd_config 

RUN rm /etc/service/sshd/down

RUN ln -sf /bin/true /usr/bin/ischroot
RUN ln -sf /bin/true /sbin/initctl

RUN sed -i '/session    required   pam_loginuid.so/c\#session    required   pam_loginuid.so' /etc/pam.d/crond

ENV PATH=/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin
CMD ["/sbin/my_init"]
