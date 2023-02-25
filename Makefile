.DEFAULT_GOAL := default
#################### PACKAGE ACTIONS ###################

reinstall_package:
	@pip uninstall -y taxifare || :
	@pip install -e .

run_preprocess:
	python -c 'from taxifare.interface.main import preprocess; preprocess()'

run_train:
	python -c 'from taxifare.interface.main import train; train()'

run_pred:
	python -c 'from taxifare.interface.main import pred; pred()'

run_evaluate:
	python -c 'from taxifare.interface.main import evaluate; evaluate()'

run_all: run_preprocess run_train run_pred run_evaluate

##################### TESTS #####################
test_gcp_setup:
	@TEST_ENV=development pytest \
	tests/all/test_gcp_setup.py::TestGcpSetup::test_setup_key_env \
	tests/all/test_gcp_setup.py::TestGcpSetup::test_setup_key_path \
	tests/all/test_gcp_setup.py::TestGcpSetup::test_code_get_project \
	tests/all/test_gcp_setup.py::TestGcpSetup::test_code_get_wagon_project


test_preprocess:
	@TEST_ENV=development pytest tests/cloud_training/test_main.py::TestMain::test_route_preprocess

test_train:
	@TEST_ENV=development pytest tests/cloud_training/test_main.py::TestMain::test_route_train

test_evaluate:
	@TEST_ENV=development pytest tests/cloud_training/test_main.py::TestMain::test_route_evaluate

test_pred:
	@TEST_ENV=development pytest tests/cloud_training/test_main.py::TestMain::test_route_evaluate

test_main_all: test_preprocess test_train test_evaluate test_pred

test_gcp_project:
	@TEST_ENV=development pytest \
	tests/all/test_gcp_setup.py::TestGcpSetup::test_setup_project_id

test_gcp_bucket:
	@TEST_ENV=development pytest \
	tests/all/test_gcp_setup.py::TestGcpSetup::test_setup_bucket_name

test_big_query:
	@TEST_ENV=development pytest \
	tests/cloud_training/test_cloud_data.py::TestCloudData::test_big_query_dataset_variable_exists \
	tests/cloud_training/test_cloud_data.py::TestCloudData::test_cloud_data_create_dataset \
	tests/cloud_training/test_cloud_data.py::TestCloudData::test_cloud_data_create_table

test_cloud_training: test_main_all test_gcp_setup test_gcp_project test_gcp_bucket test_big_query

default:
	@echo 'tests are only executed locally for this challenge'


################### DATA SOURCES ACTIONS ################

# Data sources: targets for monthly data imports
ML_DIR=~/.lewagon/mlops
HTTPS_DIR=https://storage.googleapis.com/datascience-mlops/taxi-fare-ny/
GS_DIR=gs://datascience-mlops/taxi-fare-ny

show_sources_all:
	-ls -laR ~/.lewagon/mlops/data
	-bq ls ${BQ_DATASET}
	-bq show ${BQ_DATASET}.processed_1k
	-bq show ${BQ_DATASET}.processed_200k
	-bq show ${BQ_DATASET}.processed_all
	-gsutil ls gs://${BUCKET_NAME}

reset_local_files:
	rm -rf ${ML_DIR}
	mkdir -p ~/.lewagon/mlops/data/
	mkdir ~/.lewagon/mlops/data/raw
	mkdir ~/.lewagon/mlops/data/processed
	mkdir ~/.lewagon/mlops/training_outputs
	mkdir ~/.lewagon/mlops/training_outputs/metrics
	mkdir ~/.lewagon/mlops/training_outputs/models
	mkdir ~/.lewagon/mlops/training_outputs/params

reset_local_files_with_csv_solutions: reset_local_files
	-curl ${HTTPS_DIR}solutions/data_query_fixture_2009-01-01_2015-01-01_1k.csv > ${ML_DIR}/data/raw/query_2009-01-01_2015-01-01_1k.csv
	-curl ${HTTPS_DIR}solutions/data_query_fixture_2009-01-01_2015-01-01_200k.csv > ${ML_DIR}/data/raw/query_2009-01-01_2015-01-01_200k.csv
	-curl ${HTTPS_DIR}solutions/data_query_fixture_2009-01-01_2015-01-01_all.csv > ${ML_DIR}/data/raw/query_2009-01-01_2015-01-01_all.csv
	-curl ${HTTPS_DIR}solutions/data_processed_fixture_2009-01-01_2015-01-01_1k.csv > ${ML_DIR}/data/processed/processed_2009-01-01_2015-01-01_1k.csv
	-curl ${HTTPS_DIR}solutions/data_processed_fixture_2009-01-01_2015-01-01_200k.csv > ${ML_DIR}/data/processed/processed_2009-01-01_2015-01-01_200k.csv
	-curl ${HTTPS_DIR}solutions/data_processed_fixture_2009-01-01_2015-01-01_all.csv > ${ML_DIR}/data/processed/processed_2009-01-01_2015-01-01_all.csv

reset_bq_files:
	-bq rm --project_id ${GCP_PROJECT} ${BQ_DATASET}.processed_1k
	-bq rm --project_id ${GCP_PROJECT} ${BQ_DATASET}.processed_200k
	-bq rm --project_id ${GCP_PROJECT} ${BQ_DATASET}.processed_all
	-bq mk --sync --project_id ${GCP_PROJECT} --location=${BQ_REGION} ${BQ_DATASET}.processed_1k
	-bq mk --sync --project_id ${GCP_PROJECT} --location=${BQ_REGION} ${BQ_DATASET}.processed_200k
	-bq mk --sync --project_id ${GCP_PROJECT} --location=${BQ_REGION} ${BQ_DATASET}.processed_all

reset_gcs_files:
	-gsutil rm -r gs://${BUCKET_NAME}
	-gsutil mb -p ${GCP_PROJECT} -l ${GCP_REGION} gs://${BUCKET_NAME}

reset_all_files: reset_local_files reset_bq_files reset_gcs_files

