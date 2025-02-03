# Use old, but maintained, Ubuntu LTS release
# Still widely used, e.g. Amazon Workspaces
FROM ubuntu:jammy

LABEL name="fuzzyy"

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
    make clang libncurses-dev git bash-completion less man-db ca-certificates

# Install Vim 9.0.0270 as included in old, but maintained, MacOS 13
RUN git clone --depth 1 --branch v9.0.0270 https://github.com/vim/vim.git
RUN cd vim/src && make && make install

# Minimalist vim config, makes things just about usable
RUN git clone https://github.com/tpope/vim-sensible.git /root/.vim/pack/plugins/start/sensible

# docker-run script mounts gitconfig, override editor and pager
ENV GIT_EDITOR=vim
ENV GIT_PAGER=less

# Fuzzyy needs UTF-8, but Ubuntu doesn't set LANG, so Vim defaults to Latin1
ENV LANG C.UTF-8

# Start in fuzzy dir, mounted by docker-run script
WORKDIR /root/.vim/pack/plugins/start/fuzzyy

CMD ["bash", "-l"]
