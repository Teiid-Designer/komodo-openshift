FROM jboss-datavirt63-openshift:1.1

USER root

ADD centos.repo /etc/yum.repos.d/

RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    rpm -ivh https://rhel7.iuscommunity.org/ius-release.rpm && \
    yum -y install git

# Return to original user used in parent image
USER 185
