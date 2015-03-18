#!/bin/bash
# (c) copyright 2014 martin lurie sample code not suppoted
set -x

echo have to import credentials into CM
echo admin -> kerb > import credentials
read foo

kinit hdfs@CLOUDERA
hadoop fs -mkdir /eraseme
hadoop fs -rmdir /eraseme

echo Requested user cloudera is not whitelisted and has id 501,which is below the minimum allowed 1000
echo must kinit prior to using cluster
# Application initialization failed (exitCode=255) with output: Requested user cloudera is not whitelisted and has id 501,which is below the minimum allowed 1000

kinit cloudera@CLOUDERA
hadoop jar /usr/lib/hadoop-0.20-mapreduce/hadoop-examples.jar pi 10 10000
