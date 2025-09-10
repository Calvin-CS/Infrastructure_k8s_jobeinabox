#!/bin/bash

helm upgrade \
	--install \
	--create-namespace \
	--atomic \
	--wait \
	--namespace production \
	jobeinabox \
	./jobeinabox \
	--set image.repository=harbor.cs.calvin.edu/calvincs-private 
