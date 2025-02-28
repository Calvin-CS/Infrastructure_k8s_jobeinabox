# Jobe-in-a-box: a Dockerised Jobe server (see https://github.com/trampgeek/jobe)
# With thanks to David Bowes (d.h.bowes@lancaster.ac.uk) who did all the hard work
# on this originally.



FROM openjdk:24-jdk AS jdk
FROM ubuntu:noble

ENV JAVA_VERSION=24
ENV R_VERSION=4.4.2

# Builddate
ARG BUILDDATE=20250225-1

# https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL \
    org.opencontainers.image.authors="richard.lobb@canterbury.ac.nz,j.hoedjes@hva.nl,d.h.bowes@herts.ac.uk,cwieri39@calvin.edu" \
    org.opencontainers.image.title="JobeInABox" \
    org.opencontainers.image.description="JobeInABox" \
    org.opencontainers.image.documentation="https://github.com/trampgeek/jobeinabox" \
    org.opencontainers.image.source="https://github.com/CalvinCS/Infrastructure_k8s_jobeinabox"

ARG TZ=US/Michigan

# Set up the (apache) environment variables
ENV APACHE_RUN_USER="www-data"
ENV APACHE_RUN_GROUP="www-data"
ENV APACHE_LOG_DIR="/var/log/apache2"
ENV APACHE_LOCK_DIR="/var/lock/apache2"
ENV APACHE_PID_FILE="/var/run/apache2.pid"
ENV JAVA_SRC="/usr/java/openjdk-${JAVA_VERSION}"
ENV JAVA_HOME="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64"
ENV R_HOME="/opt/R/${R_VERSION}"
ENV LANG="C.UTF-8"
ENV PATH="/opt/python/bin:/opt/R/${R_VERSION}/bin:$PATH"

#RUN echo "JAVA_VER: ${JAVA_VERSION} JAVA_SRC: ${JAVA_SRC} R_HOME: ${R_HOME} PATH: ${PATH}"

# Copy OpenJDK into Ubuntu container and setup via update-alternatives
COPY --from=jdk ${JAVA_SRC} ${JAVA_HOME}
RUN update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64/bin/java 20 && \
    update-alternatives --auto java && \
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64/bin/javac 20 && \
    update-alternatives --auto javac

# Copy apache virtual host file for later use
COPY 000-jobe.conf /
# Copy test script
COPY container-test.sh /

# Set timezone
# Install extra packages
# Redirect apache logs to stdout
# Configure apache
# - set env var for rpy2 https://github.com/rpy2/rpy2#issues-loading-shared-c-libraries
#   - note: manually copied in from running `R_HOME=/opt/R/4.2.2 python -m rpy2.situation LD_LIBRARY_PATH`
#     since /opt mounts aren't available while container is building.
# Configure php
# Get and install jobe
# Clean up
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone

RUN apt update -y -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends install -y -qq \
        acl \
        apache2 \
        build-essential \
        fp-compiler \
        git \
        libapache2-mod-php \
        nodejs \
        octave \
        php \
        php-cli \
        php-mbstring \
        pylint \
        python3 \
        python3-pip \
        python3-setuptools \
        sqlite3 \
        sudo \
        tzdata \
        unzip

RUN python3 -m pip install exec-wrappers --break-system-packages && \
    pylint --reports=no --score=n --generate-rcfile > /etc/pylintrc && \
    ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/1 /var/log/apache2/error.log && \
    sed -i "s/export LANG=C/export LANG=$LANG/" /etc/apache2/envvars && \
    echo "export LD_LIBRARY_PATH=/opt/R/${R_VERSION}/lib/R/lib:/usr/local/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64/lib/server:${LD_LIBRARY_PATH}" >> /etc/apache2/envvars && \
    sed -i '1 i ServerName localhost' /etc/apache2/apache2.conf && \
    sed -i 's/ServerTokens\ OS/ServerTokens \Prod/g' /etc/apache2/conf-enabled/security.conf && \
    sed -i 's/ServerSignature\ On/ServerSignature \Off/g' /etc/apache2/conf-enabled/security.conf && \
    rm /etc/apache2/sites-enabled/000-default.conf && \
    mv /000-jobe.conf /etc/apache2/sites-enabled/ && \
    sed -i 's/expose_php\ =\ On/expose_php\ =\ Off/g' /etc/php/8.3/cli/php.ini && \
    mkdir -p /var/crash && \
    chmod 777 /var/crash && \
    echo '<!DOCTYPE html><html lang="en"><title>CodeRunnerSandbox</title><h3>Contact <a href='mailto:cpsc-admin@calvin.edu'>cpsc-admin@calvin.edu</a>.</h3></html>' > /var/www/html/index.html && \
    git clone https://github.com/Calvin-CS/jobe.git /var/www/html/jobe && \
    apache2ctl start && \
    cd /var/www/html/jobe && \
    /usr/bin/python3 /var/www/html/jobe/install && \
    chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} /var/www/html && \
    mkdir -p /usr/local/lib/conda-wrap && create-wrappers -t conda --files-to-wrap /opt/python/bin/python --dest-dir /usr/local/lib/conda-wrap --conda-env-dir /opt/python && \
    ln -s /opt/python /opt/anaconda

RUN apt-get -y autoremove --purge && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

# Expose apache
EXPOSE 80

# Healthcheck, minimaltest.py should complete within 5 seconds
HEALTHCHECK --interval=5m --timeout=5s \
    CMD /usr/bin/python3 /var/www/html/jobe/minimaltest.py || exit 1

# Start apache
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
