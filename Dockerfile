FROM ubuntu:20.04

ARG VERSION=4.0.1
ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Brussels

RUN groupadd -g ${gid} ${group}
RUN useradd -c "Jenkins user" -d /home/${user} -u ${uid} -g ${gid} -m ${user}

ARG AGENT_WORKDIR=/home/${user}/agent

RUN apt-get update && \
    apt-get install -yq git-lfs curl openjdk-8-jdk python3 python3-pip unzip && \
    rm -rf /var/lib/apt/lists/*

# install jenkins agent
RUN curl --create-dirs -fsSLo /usr/share/jenkins/agent.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar \
  && chmod 755 /usr/share/jenkins \
  && chmod 644 /usr/share/jenkins/agent.jar \
  && ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar

COPY jenkins-agent /usr/local/bin/jenkins-agent
RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave

# semver
COPY semver-increment.sh /usr/local/bin/semver-increment
RUN chmod +x /usr/local/bin/semver-increment                 

# Install Python Requirements (incl. DBT)
COPY requirements.txt requirements.txt
RUN pip3 install -Ir requirements.txt

USER ${user}

ENV AGENT_WORKDIR=${AGENT_WORKDIR}
RUN mkdir /home/${user}/.jenkins && mkdir -p ${AGENT_WORKDIR}

VOLUME /home/${user}/.jenkins
VOLUME ${AGENT_WORKDIR}
WORKDIR /home/${user}

# git stuff
RUN mkdir ~/.ssh && ssh-keyscan bitbucket.org 2> /dev/null >> ~/.ssh/known_hosts
RUN git config --global user.email "noreply@jenkins.dev" && \
    git config --global user.name "Jenkins"

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# install snowsql
RUN curl --fail -O https://sfc-repo.snowflakecomputing.com/snowsql/bootstrap/1.2/linux_x86_64/snowsql-1.2.7-linux_x86_64.bash

ENV SNOWSQL_DEST=/home/${user}/bin 
ENV SNOWSQL_LOGIN_SHELL=/home/${user}/.bashrc

RUN bash snowsql-1.2.7-linux_x86_64.bash

RUN mkdir ~/.aws && touch ~/.aws/credentials

ENTRYPOINT ["jenkins-agent"]