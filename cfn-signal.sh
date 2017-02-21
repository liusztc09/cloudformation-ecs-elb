#!/bin/bash

datadir=awsdata
instancedatafile=${datadir}/instancedata.json
stackdatafile=${datadir}/stack-metadata.json

/bin/mkdir -p ${datadir}

curl="/usr/bin/curl --retry 3 --silent --show-error --fail"
instance_data_url=http://169.254.169.254/latest
instanceid=$($curl $instance_data_url/meta-data/instance-id | /usr/bin/tee $datadir/instanceid)

/usr/local/bin/aws ec2 describe-instances --region us-west-2 | /usr/bin/jq '.Reservations[].Instances[] | select(.InstanceId == "'$instanceid'")' | /usr/bin/tee $instancedatafile > /dev/null


zone=$(/usr/bin/jq '.Placement.AvailabilityZone' $instancedatafile) 
stackid=$(/usr/bin/jq '.Tags[] | select(.Key == "aws:cloudformation:stack-id")   | .Value' $instancedatafile)
logicalid=$(/usr/bin/jq '.Tags[] | select(.Key == "aws:cloudformation:logical-id") | .Value' $instancedatafile)


clusterprefix=$(echo $stackid | awk -F "/" '{print $2}')
clustername=$(/usr/local/bin/aws ecs list-clusters  --region us-west-2 | jq -r .clusterArns[] | grep $clusterprefix | awk -F "/" '{print $2}')
echo "ECS_CLUSTER=$clustername" > /etc/ecs/ecs.config

accountid=$(echo $stackid | awk -F ":" '{print $5}')

zlen=$(eval /bin/echo $zone | /usr/bin/wc -c)
rend=$(expr $zlen - 2)
region=$(eval /bin/echo $zone | /usr/bin/cut -c -$rend)

/bin/echo ${region} > ${datadir}/region

/bin/echo
/bin/echo "Zone: ${zone}"
/bin/echo "Region: ${region}"
/bin/echo "Stack: $(eval echo $stackid)"
/bin/echo "Instance: $(eval echo $logicalid)"
/bin/echo

#/opt/aws/bin/cfn-init -v --stack $(eval echo $stackid) --resource LaunchConfiguration --region us-west-2
#/opt/aws/bin/cfn-signal -e $? --stack ecs-test --resource AutoScalingGroup --region us-west-2
