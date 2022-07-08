#!/bin/bash

helm upgrade \
	--install \
	--create-namespace \
	--atomic \
	--wait \
	--namespace production \
	jobeinabox \
	./jobeinabox \
	--set image.repository=calvincs.azurecr.io \
	--dry-run
