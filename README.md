
[//]: # ( presentation of the unit )

# πͺ Enter the Dimension of Cloud Computing! π

In the previous unit, you have **packaged** π¦ the notebook of the _WagonCab_ Data Science team, and updated the code with **chunk-processing** so that the model could be trained on the full _TaxiFare_ dataset despite running "small" local machine.

βοΈ In this unit, you will learn how to dispatch work to a pool of **cloud resources** instead of using your local machine.

πͺ As you can (in theory) now access machine with the RAM-size of your choice, we'll consider that you don't need any "chunk-by-chunk" logic anymore!

π― Today, you will refactor previous unit codebase so as to:
- Fetch all your environment variable from a single `.env` file instead of updating `params.py`
- Load raw data from Le Wagon Big Query all at once on memory (no chunk)
- Cache a local CSV copy to avoid query it twice
- Process data
- Upload processed data on your own Big Query table
- Download processed data (all at once)
- Cache a local CSV copy to avoid query it twice
- Train your model on this processed data
- Store model weights on your own Google Cloud Storage (GCS bucket)

Then, you'll provision a Virtual Machine (VM) so as to run all this workflow on the VM !

Congratulation, you just grow from a **Data Scientist** into an full **ML Engineer**!
You can now sell your big GPU-laptop and buy a lightweight computer like real ML practitioners π

---

<br>

# 1οΈβ£ New taxifare package setup

<details>
  <summary markdown='span'><strong>βInstructions (expand me)</strong></summary>


## Project Structure

π From now on, you will start each new challenge with the solution of the previous challenge

π Each new challenge will bring in an additional set of features

Here are the main files of interest:
```bash
.
βββ .env                            # βοΈ Single source of all config variables
βββ .envrc                          # π¬ .env automatic loader (used by direnv)
βββ Makefile                        # New commands "run_train", "run_process", etc..
βββ README.md
βββ requirements.txt
βββ setup.py
βββ taxifare
β   βββ __init__.py
β   βββ interface
β   β   βββ main_local.py           # πͺ (OLD) entry point
β   β   βββ main.py                 # πͺ (NEW) entry point: No more chunks π - Just process(), train()
β   βββ ml_logic
β       βββ data.py                 # (UPDATED) Loading and storing data from/to Big Query !
β       βββ registry.py             # (UPDATED) Loading and storing model weights from/to Cloud Storage!
β       βββ ...
β   βββ params.py                   # Simply load all .env variables into python objects
β   βββ utils.py
βββ tests
```


#### βοΈ `.env.sample`

This file is a _template_ designed to help you create a `.env` file for each challenge. The `.env.sample` file contains the variables required by the code and expected in the `.env` file. π¨ Keep in mind that the `.env` file **should never be tracked with Git** to avoid exposing its content, so we have added it to your `.gitignore`.

#### πͺ `main.py`

Bye bye `taxifare.interface.main_local` module, you served us well β€οΈ

Long live `taxifare.interface.main`, our new package entry point β­οΈ to:

- `preprocess`: preprocess the data and store `data_processed`
- `train`: train on processed data and store model weights
- `evaluate`: evaluate the performance of the latest trained model on new data
- `pred`: make a prediction on a `DataFrame` with a specific version of the trained model


π¨ One main change in the code of the package is that we chose to delegate some of its work to dedicated modules in order to limit the size of the `main.py` file. The main changes concern:

- The project configuration: Single source of truth is `.env`
  - `.envrc` tells `direnv` to loads the `.env` as environment variables
  - `params.py` then loads all these variable in python, and should not be changed manually anymore

- `registry.py`: the code evolved to store the trained model either locally or - _spoiler alert_ - in the cloud
  - Notice the new env variable `MODEL_TARGET` (`local` or `gcs`)

- `data.py` has refactored 2 methods that we'll use heavily in `main.py`
  - `get_data_with_cache()` (get some data from Big Query or cached CSV if exists)
  - `load_data_to_bq()` (upload some data to BQ)



## Setup

#### Install `taxifare` version `0.0.7`

**π» Install the new package version**
```bash
make reinstall_package # always check what make do in Makefile
```

**π§ͺ Check the package version**
```bash
pip list | grep taxifare
# taxifare               0.0.7
```

#### Setup direnv & .env

Our goal is to be able to configure the behavior of our _package_ π¦ depending on the value of the variables defined in a `.env` project configuration file.

**π» In order to do so, we will install the `direnv` shell extension.** Its job is to locate the nearest `.env` file in the parent directory structure of the project and load its content into the environment.

``` bash
# MacOS
brew install direnv

# Ubuntu (Linux or Windows WSL2)
sudo apt update
sudo apt install -y direnv
```
Once `direnv` is installed, we need to tell `zsh` to load `direnv` whenever the shell starts

``` bash
code ~/.zshrc
```

The list of plugins is located in the beginning of the file and should look this this when you add `direnv`:

``` bash
plugins=(...direnv)
```

Start a new `zsh` window in order to load `direnv`

**π» At this point, `direnv` is still not able to load anything, as there is no `.env` file, so let's create one:**

- Duplicate the `env.sample` file and rename the duplicate as `.env`
- Enable the project configuration with `direnv allow .` (the `.` stands for _current directory_)

π§ͺ Check that `direnv` is able to read the environment variables from the `.env` file:

```bash
echo $DATA_SIZE
# 1k --> Let's keep it small!
```

From now on, every time you need to update the behavior of the project:
1. Edit `.env`, save it
2. Then
```bash
direnv reload . # to reload your env variables π¨π¨
```

**βοΈ You *will* forget that. Prove us wrong π**

```bash
# Ok so, for this unit, alway keep data size values small (good practice for dev purposes)
DATA_SIZE=1k
CHUNK_SIZE=200
```

</details>

# 2οΈβ£ GCP Setup

<details>
<summary markdown='span'><strong>βInstructions (expand me)</strong></summary>

**Google Cloud Platform** will allow you to allocate and use remote resources in the cloud. You can interact with it via:
- π [console.cloud.google.com](console.cloud.google.com)
- π» Command Line Tools
  - `gcloud`
  - `bq` (big query - SQL)
  - `gsutils` (cloud storage - buckets)


### a) `gcloud` CLI

- Find the `gcloud` command that lists your own **GCP project ID**.
- π Fill in the `GCP_PROJECT` variable in the `.env` project configuration with the ID of your GCP project
- π§ͺ Run the tests with `make test_gcp_project`

<details>
  <summary markdown='span'><strong>π‘ Hint </strong></summary>


  You can use the `-h` or the `--help` (more details) flags in order to get contextual help on the `gcloud` commands or sub-commands; use `gcloud billing -h` to get the `gcloud billing` sub-command's help, or `gcloud billing --help` for more detailed help.

  π Pressing `q` is usually the way to exit help mode if the command did not terminate itself (`Ctrl + C` also works)

  Also note that running `gcloud` without arguments lists all the available sub-commands by group.

</details>

### b) Cloud Storage (GCS) and the `gsutil` CLI

The second CLI tool that you will use often allows you to deal with files stored within **buckets** on Cloud Storage.

We'll use it to store large & unstructured data such as model weights :)

**π» Create a bucket in your GCP account using `gsutil`**

- Make sure to create the bucket where you are located yourself (use `GCP_REGION` in the `.env`)
- Fill also the `BUCKET_NAME` variable
- `direnv reload .` ;)

Tips: The CLI can interpolate `.env` variables by prefix them with a `$` sign (e.g. `$GCP_REGION`)
<details>
  <summary markdown='span'>π Solution</summary>

```bash
gsutil ls                               # list buckets

gsutil mb \                             # make bucket
    -l $GCP_REGION \
    -p $GCP_PROJECT \
    gs://$BUCKET_NAME                     # make bucket

gsutil rm -r gs://$BUCKET_NAME               # delete bucket
```
You can also use the [Cloud Storage console](https://console.cloud.google.com/storage/) in order create a bucket or list the existing buckets and their content.

Do you see how much slower the GCP console (web interface) is compared to the command line?

</details>

**π§ͺ Run the tests with `make test_gcp_bucket`**

### c) Big Query and the `bq` CLI

Biq Query is a data-warehouse, used to store structured data, that can be queried rapidly.

π‘ To be more precise, Big Query is an online massively-parallel **Analytical Database** (as opposed to **Transactional Database**)

- Data is stored by columns (as opposed to rows on PostGres for instance)
- It's optimized for large transformation such as `group-by`, `join`, `where` etc...easily
- But it's not optimized for frequent row-by-row insert/delete

Le WagonCab is actually using a managed postgreSQL (e.g. [Google Cloud SQL](https://cloud.google.com/sql)) as its main production database on which it's Django app is storing / reading hundred thousands of individual transactions per day!

Every night, Le WagonCab launch a "database replication" job that applies the daily diffs of the "main" postgresSQL into the "slave" Big Query warehouse. Why?
- Because you don't want to run queries directly against your production-database! That could slow down your users.
- Because analysis is faster/cheaper on columnar databases
- Because you also want to integrate other data in your warehouse to JOIN them (e.g marketing data from Google Ads...)

π Back to our business:

**π» Let's create our own dataset where we'll store & query preprocessed data !**

- Using `bq` and the following env variables, create a new _dataset_ called `taxifare` on your own `GCP_PROJECT`

```bash
BQ_DATASET=...
BQ_REGION=...
GCP_PROJECT=...
```

- Then add 3 new _tables_ `processed_1k`, `processed_200k`, `processed_all`

<details>
  <summary markdown='span'>π‘ Hints</summary>

Although the `bq` command is part of the **Google Cloud SDK** that you installed on your machine, it does not seem to follow the same help pattern as the `gcloud` and `gsutil` commands.

Try running `bq` without arguments to list the available sub-commands.

What you are looking for is probably in the `mk` (make) section.
</details>

<details>
  <summary markdown='span'><strong>π Solution </strong></summary>

``` bash
bq mk \
    --project_id $GCP_PROJECT \
    --data_location $BQ_REGION \
    $BQ_DATASET

bq mk --location=$GCP_REGION $BQ_DATASET.processed_1k
bq mk --location=$GCP_REGION $BQ_DATASET.processed_200k
bq mk --location=$GCP_REGION $BQ_DATASET.processed_all

bq show
bq show $BQ_DATASET
bq show $BQ_DATASET.processed_1k

```

</details>

**π§ͺ Run the tests with `make test_big_query`**


π Look at `make reset_all_files` directive --> It resets all local files (csvs, models, ...) and data from bq tables and buckets, but preserve local folder structure, bq tables schema, and gsutil buckets.

Very useful to reset state of your challenge if you are uncertain and you want to debug yourself!

π Run `make reset_all_files` safely now, it will remove files from unit 01 and make it clearer

π Run `make show_sources_all` to see that you're back from a blank state!

</details>

# 3οΈβ£ βοΈ Train locally, with data on the cloud !

<details>
  <summary markdown='span'><strong>βInstructions (expand me)</strong></summary>

π― Your goal is to fill-up `taxifare.interface.main` so that you can run every 4 routes _one by one_

```python
if __name__ == '__main__':
    # preprocess()
    # train()
    # evaluate()
    # pred()
```

To do so, you can either:

- π₯΅ Uncomment the routes above, one after the other, and run `python -m taxifare.interface.main` from your Terminal

- π Smarter: use each of the following `make` commands that we created for you below

π‘ Make sure to read each function docstring carefully
π‘ Don't try to parallelize route completion. Fix them one after the other.
π‘ Take time to read carefully the tracebacks, and add breakpoint() to your code or to the test itself (you are 'engineers' now)!

**Preprocess**

π‘ Feel free to refer back to `main_local.py` when needed! Some of the syntax can be re-used

```bash
# Call your preprocess()
make run_preprocess
# Then test this route, but with all combinations of states (.env, cached_csv or not)
make test_preprocess
```

**Train**

π‘ Be sure to understand what happens when MODEL_TARGET = 'gcs' vs 'local'
π‘ We advise you to set `verbose=0` on model training to shorter your logs!

```bash
make run_train
make test_train
```

**Evaluate**

Be sure to understand what happens when MODEL_TARGET = 'gcs' vs 'local'
```bash
make run_evaluate
make test_evaluate
```

**Pred**
This one is easy
```bash
make run_pred
make test_pred
```

π§ͺ Run all tests at once if you want βοΈ

```bash
make run_all
make test_main_all
```

π Congrats for the heavy refactoring! You now have a very robust package that can be deployed in the cloud to be used with `DATA_SIZE='all'` πͺ

</details>

# 4οΈβ£ Train in the Cloud with Virtual Machines


<details>
  <summary markdown='span'><strong>βInstructions (expand me)</strong></summary>


## Enable the Compute Engine Service

In GCP, many services are not enabled by default. The service to activate in order to use _virtual machines_ is **Compute Engine**.

**βHow do you enable a GCP service?**

Find the `gcloud` command to enable a **service**.

<details>
  <summary markdown='span'>π‘ Hints</summary>

[Enabling an API](https://cloud.google.com/endpoints/docs/openapi/enable-api#gcloud)
</details>

## Create your First Virtual Machine

The `taxifare` package is ready to train on a machine in the cloud. Let's create our first *Virtual Machine* instance!

**βCreate a Virtual Machine**

Head over to the GCP console, specifically the [Compute Engine page](https://console.cloud.google.com/compute). The console will allow you to easily explore the available options. Make sure to create an **Ubuntu** instance (read the _how-to_ below and have a look at the _hint_ after it).

<details>
  <summary markdown='span'><strong> πΊ How to configure your VM instance </strong></summary>


  Let's explore the options available. The top right of the interface gives you a monthly estimate of the cost for the selected parameters if the VM remains online all the time.

  The default options should be enough for what we want to do now, except for one: we want to choose the operating system that the VM instance will be running.

  Go to the **"Boot disk"** section, click on **"CHANGE"** at the bottom, change the **operating system** to **Ubuntu**, and select the latest **Ubuntu xx.xx LTS x86/64** (Long Term Support) version.

  Ubuntu is the [Linux distro](https://en.wikipedia.org/wiki/Linux_distribution) that will resemble the configuration on your machine the most, following the [Le Wagon setup](https://github.com/lewagon/data-setup). Whether you are on a Mac, using Windows WSL2 or on native Linux, selecting this option will allow you to play with a remote machine using the commands you are already familiar with.
</details>

<details>
  <summary markdown='span'><strong>π‘ Hint </strong></summary>

  In the future, when you know exactly what type of VM you want to create, you will be able to use the `gcloud compute instances` command if you want to do everything from the command line; for example:

  ``` bash
  INSTANCE=taxi-instance
  IMAGE_PROJECT=ubuntu-os-cloud
  IMAGE_FAMILY=ubuntu-2204-lts

  gcloud compute instances create $INSTANCE --image-project=$IMAGE_PROJECT --image-family=$IMAGE_FAMILY
  ```
</details>

**π» Fill in the `INSTANCE` variable in the `.env` project configuration**


## Setup your VM

You have access to virtually unlimited computing power at your fingertips, ready to help with trainings or any other task you might think of.

**βHow do you connect to the VM?**

The GCP console allows you to connect to the VM instance through a web interface:

<a href="https://wagon-public-datasets.s3.amazonaws.com/data-science-images/DE/gce-vm-ssh.png"><img src="https://wagon-public-datasets.s3.amazonaws.com/data-science-images/DE/gce-vm-ssh.png" height="450" alt="gce vm ssh"></a><a href="https://wagon-public-datasets.s3.amazonaws.com/07-ML-Ops/02-Cloud-Training/GCE_SSH_in_browser.png"><img style="margin-left: 15px;" src="https://wagon-public-datasets.s3.amazonaws.com/07-ML-Ops/02-Cloud-Training/GCE_SSH_in_browser.png" height="450" alt="gce console ssh"></a>

You can disconnect by typing `exit` or closing the window.

A nice alternative is to connect to the virtual machine right from your command line π€©

<a href="https://wagon-public-datasets.s3.amazonaws.com/07-ML-Ops/02-Cloud-Training/GCE_SSH_in_terminal.png"><img src="https://wagon-public-datasets.s3.amazonaws.com/07-ML-Ops/02-Cloud-Training/GCE_SSH_in_terminal.png" height="450" alt="gce ssh"></a>

All you need to do is to `gcloud compute ssh` on a running instance and to run `exit` when you want to disconnect π

``` bash
INSTANCE=taxi-instance

gcloud compute ssh $INSTANCE
```

<details>
  <summary markdown='span'><strong>π‘ Error 22 </strong></summary>


  If you encounter a `port 22: Connection refused` error, just wait a little more for the VM instance to complete its startup.

  Just run `pwd` or `hostname` if you ever wonder on which machine you are running your commands.
</details>

**βHow do you setup the VM to run your python code?**

Let's run a light version of the [Le Wagon setup](https://github.com/lewagon/data-setup).

**π» Connect to your VM instance and run the commands of the following sections**

<details>
  <summary markdown='span'><strong> βοΈ <code>zsh</code> and <code>omz</code> (expand me)</strong></summary>

The **zsh** shell and its **Oh My Zsh** framework are the _CLI_ configuration you are already familiar with. When prompted, make sure to accept making `zsh` the default shell.

``` bash
sudo apt update
sudo apt install -y zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

π Now the _CLI_ of the remote machine starts to look a little more like the _CLI_ of your local machine
</details>

<details>
  <summary markdown='span'><strong> βοΈ <code>pyenv</code> and <code>pyenv-virtualenv</code> (expand me)</strong></summary>

Clone the `pyenv` and `pyenv-virtualenv` repos on the VM:

``` bash
git clone https://github.com/pyenv/pyenv.git ~/.pyenv
git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv
```

Open ~/.zshrc in a Terminal code editor:

``` bash
nano ~/.zshrc
```

Add `pyenv`, `ssh-agent` and `direnv` to the list of `zsh` plugins on the line with `plugins=(git)` in `~/.zshrc`: in the end, you should have `plugins=(git pyenv ssh-agent direnv)`. Then, exit and save (`Ctrl + X`, `Y`, `Enter`).

Make sure that the modifications were indeed saved:

``` bash
cat ~/.zshrc | grep "plugins="
```

Add the pyenv initialization script to your `~/.zprofile`:

``` bash
cat << EOF >> ~/.zprofile
export PYENV_ROOT="\$HOME/.pyenv"
export PATH="\$PYENV_ROOT/bin:\$PATH"
eval "\$(pyenv init --path)"
EOF
```

π Now we are ready to install Python

</details>

<details>
  <summary markdown='span'><strong> βοΈ <code>Python</code> (expand me)</strong></summary>

Add dependencies required to build Python:

``` bash
sudo apt-get update; sudo apt-get install make build-essential libssl-dev zlib1g-dev \
libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
python3-dev
```

βΉοΈ If a window pops up to ask you which services to restart, just press *Enter*:

<a href="https://wagon-public-datasets.s3.amazonaws.com/data-science-images/DE/gce-apt-services-restart.png"><img src="https://wagon-public-datasets.s3.amazonaws.com/data-science-images/DE/gce-apt-services-restart.png" width="450" alt="gce apt services restart"></a>

Now we need to start a new user session so that the updates in `~/.zshrc` and `~/.zprofile` are taken into account. Run the command below π:

``` bash
zsh --login
```

Then reconnect:

``` bash
gcloud compute ssh $INSTANCE
```

Install the same python version that you use for the bootcamp, and create a `lewagon` virtual env. This can take a while and look like it is stuck, but it is not:

``` bash
# e.g. with 3.10.6
pyenv install 3.10.6
pyenv global 3.10.6
pyenv virtualenv 3.10.6 lewagon
pyenv global lewagon
```

</details>

<details>
  <summary markdown='span'><strong> βοΈ <code>git</code> authentication with GitHub (expand me)</strong></summary>

Copy your private key π to the _VM_ in order to allow it to access your GitHub account.

β οΈ Run this single command on your machine, not in the VM β οΈ

``` bash
INSTANCE=taxi-instance

# scp stands for secure copy (cp)
gcloud compute scp ~/.ssh/id_ed25519 $USER@$INSTANCE:~/.ssh/
```

β οΈ Then, resume running commands in the VM β οΈ

Register the key you just copied after starting `ssh-agent`:

``` bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Enter your *passphrase* if asked to.

π You are now able to interact with your **GitHub** account from the _virtual machine_
</details>

<details>
  <summary markdown='span'><strong> βοΈ <em>Python</em> code authentication to GCP (expand me)</strong></summary>

The code of your package needs to be able to access your Big Query data warehouse.

To do so, we will login to your account using the command below π

``` bash
gcloud auth application-default login
```

βοΈ Note: In a full production environment we would create a service account applying the least privilege principle for the vm but this is the easiest approach for development.

Let's verify that your Python code can now access your GCP resources. First, install some packages:

``` bash
pip install google-cloud-storage
```

Then, [run Python code from the _CLI_](https://stackoverflow.com/questions/3987041/run-function-from-the-command-line). This should list your GCP buckets:

``` bash
python -c "from google.cloud import storage; \
    buckets = storage.Client().list_buckets(); \
    [print(b.name) for b in buckets]"
```

</details>

<details>
  <summary markdown='span'><strong> βοΈ Make a generic data science setup (expand me)</strong></summary>

Install all the packages of the bootcamp on your VM:

``` bash
pip install -U pip
pip install -r https://raw.githubusercontent.com/lewagon/data-setup/master/specs/releases/linux.txt
```

</details>

Your _VM_ is now fully operational with:
- An environment (Python + package dependencies) to run your code
- The credentials to connect to your _GitHub_ account
- The credentials to connect to your _GCP_ account

The only thing that is missing is the code of your project!

**π§ͺ Let's run a few tests inside your _VM Terminal_ before we install it:**

- Default shell is `/usr/bin/zsh`
    ```bash
    echo $SHELL
    ```
- Python version is `3.10.6`
    ```bash
    python --version
    ```
- Active GCP project is the same as `$GCP_PROJECT` in your `.env` file
    ```bash
    gcloud config list project
    ```

Your VM is now a data science beast π₯

## Train in the Cloud

Let's run your first training in the cloud!

**βHow do you setup and run your project on the virtual machine?**

**π» Clone your package, install its requirements**

<details>
  <summary markdown='span'><strong>π‘ Hint </strong></summary>

You can copy your code to the VM by cloning your GitHub project with this syntax:

Myriad batch:
```bash
git clone git@github.com:<user.github_nickname>/{{local_path_to("07-ML-Ops/02-Cloud-training/01-Cloud-training")}}
```

Legacy batch:
```bash
git clone git@github.com:<user.github_nickname>/data-challenges
```

Enter the directory of your package (adapt the command):

``` bash
cd <path/to/the/package/model/dir>
```

Create directories to save the model and its parameters/metrics:

``` bash
mkdir -p data
mkdir -p training_outputs/models
mkdir -p training_outputs/params
mkdir -p training_outputs/metrics
```

Create a `.env` file with all required parameters to use your package:

``` bash
cp .env.sample .env
```

Fill in the content of the `.env` file (complete the missing values, change any values that are specific to your virtual machine):

``` bash
nano .env
```

``` bash
LOCAL_DATA_PATH=data
LOCAL_REGISTRY_PATH=training_outputs
```

Install `direnv` to load your `.env`:

``` bash
sudo apt update
sudo apt install -y direnv
```

βΉοΈ If a window pops up to ask you which services to restart, just press *Enter*.

Disconnect from the _VM_, then reconnect (so that `direnv` works):

``` bash
exit
```

``` bash
gcloud compute ssh $INSTANCE
```

Allow your `.envrc`:

``` bash
direnv allow .
```

Remove the existing local environment:

``` bash
rm .python-version
```

Install the dependencies of the package:

``` bash
pip install pyarrow tensorflow  # this should be in your requirements.txt
pip install -r requirements.txt
```

</details>

**π₯ Run the preprocessing and the training in the cloud π₯**!

``` bash
make run_all  # Have a look at the Makefile to understand exactly what this does!
```

<a href="https://wagon-public-datasets.s3.amazonaws.com/data-science-images/DE/gce-train-ssh.png"><img src="https://wagon-public-datasets.s3.amazonaws.com/data-science-images/DE/gce-train-ssh.png" height="450" alt="gce train ssh"></a><a href="https://wagon-public-datasets.s3.amazonaws.com/07-ML-Ops/02-Cloud-Training/GCE_run_all_in_Terminal.png"><img style="margin-left: 15px;" src="https://wagon-public-datasets.s3.amazonaws.com/07-ML-Ops/02-Cloud-Training/GCE_run_all_in_Terminal.png" height="450" alt="gce train web ssh"></a>

> `Project not set` error from GCP services? You can add a `GCLOUD_PROJECT` environment variable that should be the same as your `GCP_PROJECT`

**ππ½ββοΈ Go Big: re-run everything, switching to 500K data sizes and 100K chunks ππ½ββοΈ**!


**π Switch OFF your VM to finish π**

You can easily start and stop a VM instance from the GCP console, which allows you to see which instances are running.

<a href="https://wagon-public-datasets.s3.amazonaws.com/data-science-images/DE/gce-vm-start.png"><img src="https://wagon-public-datasets.s3.amazonaws.com/data-science-images/DE/gce-vm-start.png" height="450" alt="gce vm start"></a>

<details>
  <summary markdown='span'><strong>π‘ Hint </strong></summary>

A faster way to start and stop your virtual machine is to use the command line. The commands still take some time to complete, but you do not have to navigate through the GCP console interface.

Have a look at the `gcloud compute instances` command in order to start, stop, or list your instances:

``` bash
INSTANCE=taxi-instance

gcloud compute instances stop $INSTANCE
gcloud compute instances list
gcloud compute instances start $INSTANCE
```
</details>

π¨ Computing power does not grow on trees π³, do not forget to switch the VM **off** whenever you stop using it! πΈ

</details>
# data-train-in-the-cloud
