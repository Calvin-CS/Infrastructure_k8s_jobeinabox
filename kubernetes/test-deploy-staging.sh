#!/bin/bash

helm upgrade \
	--install \
	--create-namespace \
	--atomic \
	--wait \
	--namespace staging \
	jobeinabox \
	./jobeinabox \
	--set image.repository=calvincs.azurecr.io 
