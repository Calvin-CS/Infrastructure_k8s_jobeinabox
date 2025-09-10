#!/bin/bash

helm upgrade \
	--install \
	--create-namespace \
	--atomic \
	--wait \
	--namespace staging \
	jobeinabox \
	./jobeinabox \
	--set image.repository=harbor.cs.calvin.edu/calvincs-private \
	--set image.tag=staging
