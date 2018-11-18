# JupyterLab with Tensorflow


## Pre-requisites

- Install `nvidia-dirvers` for your graphic card and make sure that `nvidia-smi` outputs information about the installed driver.


## Installation 


### nvidia-docker

Add `nvidia-docker` repo and install `nvidia-docker2` plugin.

```
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey |   sudo apt-key add -
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
echo $distribution
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list |   sudo tee /etc/apt/sources.list.d/nvidia-docker.list
apt-get update
apt-get install -y nvidia-docker2
service docker restart

```

Then add `nvidia` as  `default-runtime` in the file `/etc/docker/daemon.json`. Edit like this:

```
{
  "default-runtime": "nvidia",
  "runtimes": ... 
}
```



### Test GPU support

You can check if your local configuration is correct and your containers would have GPU support with this commmands:

```
docker run --rm nvidia/cuda:9.0-base nvidia-smi

# Output something like this:
# +-----------------------------------------------------------------------------+
# | NVIDIA-SMI 415.13       Driver Version: 415.13       CUDA Version: 10.0     |
# |-------------------------------+----------------------+----------------------+
# | GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
# |===============================+======================+======================|
# |   0  GeForce GTX 105...  Off  | 00000000:01:00.0 Off |                  N/A |
# | N/A   40C    P8    N/A /  N/A |   3743MiB /  4042MiB |      0%      Default |
# +-------------------------------+----------------------+----------------------+
#                                                                                
# +-----------------------------------------------------------------------------+
# | Processes:                                                       GPU Memory |
# |  GPU       PID   Type   Process name                             Usage      |
# |=============================================================================|
# +-----------------------------------------------------------------------------+

```

## Build image

### Setup .env

First copy `.env-example` to `.env` and fill the info with the data obtained from `id`

```
$ id
#   uid=1000(mr_robot) gid=1002(mr_robot) groups=1002(mr_robot)

# edit .env like this:
NB_USER=mr_robot
NB_UID=1000
NB_GID=1000
```

This is necessary so the notebooks would be mounted with write permissions for your host user


### build with docker

```
docker build -t jupyter-lab . 
```

*NOTE:* This is the moment to grab that coffee. It'd take long to build.


## Test JupyterLab GPU support

To test if everything is ok and there is GPU support run this command:

```
docker run --rm jupyter-lab nvidia-smi

# Output similar to the above example
```

## Usage

Once you have your image built. Add a persistence volume to save your notebooks and start the service.

### Run docker-compose

```
docker-compose up
```

## Adding notebooks

You can add notebooks as volumes shared to the container. Edit `docker-compose.yml`. You can use $NB_USER in the path:

```
    volumes:
      - ./my_notebooks:/home/$NB_USER/my_notebooks
      - ./datasets:/home/$NB_USER/datasets
```

