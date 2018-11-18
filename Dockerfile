## BUILD FROM jupyter and tensorflow dockerfiles 

# https://github.com/jupyter/docker-stacks/blob/master/base-notebook/Dockerfile 
# https://github.com/tensorflow/tensorflow/blob/master/tensorflow/tools/dockerfiles/dockerfiles/nvidia-jupyter.Dockerfile

FROM nvidia/cuda:9.0-base-ubuntu16.04

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

RUN echo $NB_USER

ADD bin/fix-permissions /usr/local/bin/fix-permissions

ENV JUPYTER_ENABLE_LAB true

USER root

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND noninteractive

# See http://bugs.python.org/issue19846
ENV LANG C.UTF-8

RUN apt-get update && apt-get -yq dist-upgrade \
 && apt-get install -yq --no-install-recommends \
    wget \
    bzip2 \
    ca-certificates \
    sudo \
    locales \
    fonts-liberation \
    # Pick up some TF dependencies
    build-essential \
    cuda-command-line-tools-9-0 \
    cuda-cublas-9-0 \
    cuda-cufft-9-0 \
    cuda-curand-9-0 \
    cuda-cusolver-9-0 \
    cuda-cusparse-9-0 \
    libcudnn7=7.2.1.38-1+cuda9.0 \
    libnccl2=2.2.13-1+cuda9.0 \
    libfreetype6-dev \
    libhdf5-serial-dev \
    libpng12-dev \
    libzmq3-dev \
    pkg-config \
    software-properties-common \
    unzip \
 && \
   apt-get clean && \
   rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

RUN apt-get update && \
    apt-get install nvinfer-runtime-trt-repo-ubuntu1604-4.0.1-ga-cuda9.0 && \
    apt-get update && \
    apt-get install libnvinfer4=4.1.2-1+cuda9.0

#ARG PYTHON=python3
#ARG PIP=pip3
#
#RUN apt-get update && apt-get install -y \
#    ${PYTHON} \
#    ${PYTHON}-pip

# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=$NB_USER \
    NB_UID=$NB_UID \
    NB_GID=$NB_GID \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER

# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN groupadd wheel -g 11 && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd && \
    fix-permissions $HOME && \
    fix-permissions $CONDA_DIR

# Setup work directory for backward-compatibility
RUN mkdir /home/$NB_USER/test && \
    mkdir /home/$NB_USER/.keras

COPY test-notebooks /home/$NB_USER/test
COPY config/keras.json /home/$NB_USER/.keras/
COPY config/theanorc /home/$NB_USER/.theanorc

USER $NB_UID


#RUN ${PIP} install --upgrade \
#    pip \
#    tensorflow-gpu \
#    setuptools

# Install conda as jovyan and check the md5 sum provided on the download site
ENV MINICONDA_VERSION 4.5.11
RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "e1045ee415162f944b6aebfe560b8fee *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda install --quiet --yes conda="${MINICONDA_VERSION%.*}.*" && \
    $CONDA_DIR/bin/conda update --all --quiet --yes && \
    conda clean -tipsy && \
    rm -rf /home/$NB_USER/.cache/yarn

# Install Tini
RUN conda install --quiet --yes 'tini=0.18.0' && \
    conda list tini | grep tini | tr -s ' ' | cut -d ' ' -f 1,2 >> $CONDA_DIR/conda-meta/pinned && \
    conda clean -tipsy

# Install Jupyter Notebook, Lab, and Hub
# Generate a notebook server config
# Cleanup temporary files
# Correct permissions
# Do all this in a single RUN command to avoid duplicating all of the
# files across image layers when the permissions change
COPY requirements.txt .

RUN conda install --quiet --yes --file requirements.txt && \
    conda clean -tipsy && \
    jupyter labextension install @jupyterlab/hub-extension@^0.12.0 && \
    npm cache clean --force && \
    jupyter notebook --generate-config && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn

USER root

RUN fix-permissions /home/$NB_USER && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER/.keras && \
    fix-permissions /home/$NB_USER/.theanorc 
#    fix-permissions /home/$NB_USER/notebooks

RUN jupyter-nbextension enable tree-filter/index && \
    jupyter-nbextension enable code_prettify/code_prettify && \
    jupyter-nbextension enable help_panel/help_panel && \
    jupyter-nbextension enable highlight_selected_word/main --highlight_selected_word.use_toggle_hotkey=true && \
    jupyter-nbextension enable autosavetime/main && \
    jupyter-nbextension enable livemdpreview/livemdpreview && \
    jupyter-nbextension enable printview/main && \
    jupyter-nbextension enable code_prettify/2to3 && \
    jupyter-nbextension enable execute_time/ExecuteTime && \
    jupyter-nbextension enable highlighter/highlighter && \
    jupyter-nbextension enable python-markdown/main && \
    jupyter-nbextension enable codefolding/main && \
    jupyter-nbextension enable codefolding/edit && \
    jupyter-nbextension enable toc2/main && \
    jupyter-nbextension enable init_cell/main && \
    jupyter-nbextension enable navigation-hotkeys/main && \
    jupyter-nbextension enable rubberband/main && \
    jupyter-nbextension enable scroll_down/main && \
    jupyter-nbextension enable notify/notify && \
    jupyter-nbextension enable ruler/main && \
    jupyter-nbextension enable select_keymap/main && \
    jupyter-nbextension enable varInspector/main && \
    jupyter-nbextension enable code_font_size/code_font_size && \
    jupyter-nbextension enable hinterland/hinterland && \
    jupyter-nbextension enable move_selected_cells/main && \
    jupyter-nbextension enable scratchpad/main 

# Add local files as late as possible to avoid cache busting
COPY bin/start.sh /usr/local/bin/
COPY bin/start-notebook.sh /usr/local/bin/
COPY bin/start-singleuser.sh /usr/local/bin/
COPY config/jupyter_notebook_config.py /etc/jupyter/

RUN fix-permissions /etc/jupyter/

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_UID

RUN mkdir /home/$NB_USER/notebooks

EXPOSE 8888
WORKDIR $HOME

# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]


#VOLUME /home/$NB_USER/notebooks

