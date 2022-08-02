FROM ubuntu:20.04
COPY scripts /app/

ARG BASH_PACKAGES="wget unzip postgresql-client default-jre"
RUN apt-get update && \
    apt-get install -y --no-install-recommends ${BASH_PACKAGES}
    # apt-get clean &&

# WORKDIR /app
# RUN ./load_fed_themes.sh -e

# ENTRYPOINT ["tail", "-f", "/dev/null"]
ENTRYPOINT ["app/load_fed_themes.sh", "-e"]