#!/bin/bash

set -x

# Grab our libs
. "`dirname $0`/setup-lib.sh"

INTERMESH_KEY="`dirname $0`/deploy_keys/intermesh_id_ed25519"
DEATHSTARBENCH_KEY="`dirname $0`/deploy_keys/deathstarbench_id_ed25519"

if [ -f $OURDIR/intermesh-done ]; then
    exit 0
fi

logtstart "intermesh"

cd ~
# install istio
curl -L https://istio.io/downloadIstio | sh -
echo 'PATH="$PATH:$HOME/istio-1.16.0/bin"' >> ~/.bashrc
export PATH="$PATH:$HOME/istio-1.16.0/bin"
echo "export REMOTEINTERMESDOMAIN=$REMOTEINTERMESHDDOMAIN"
source ~/.bashrc

istioctl install --set profile=demo -y
kubectl label namespace default istio-injection=enabled



sudo apt update
sudo apt install -y python3-pip

# add github key fingerprint to known hosts to avoid trust host? yes/no question
# sure! you can mitm me
ssh-keyscan github.com >> ~/.ssh/known_hosts
echo "key is $INTERMESH_KEY"

chmod 400 $INTERMESH_KEY
chmod 400 $DEATHSTARBENCH_KEY
git clone git@github.com:intermesh-systems/im-deathstarbench.git --config core.sshCommand="ssh -i $DEATHSTARBENCH_KEY"
pushd im-deathstarbench/hotelReservation/

	# Put the docker images for jaeger, consul, memcached, mongo into the local registry.
	# First pull from docker hub.
	docker pull consul:latest
	# Then tag and push to local registry.
	docker tag consul:latest localhost:5001/consul:latest
	# Push to local registry.
	docker push localhost:5001/consul:latest

	# Do the same for jaeger.
	docker pull jaegertracing/all-in-one:latest
	docker tag jaegertracing/all-in-one:latest localhost:5001/jaegertracing/all-in-one:latest
	docker push localhost:5001/jaegertracing/all-in-one:latest

	# Do the same for memcached.
	docker pull memcached:latest
	docker tag memcached:latest localhost:5001/memcached:latest
	docker push localhost:5001/memcached:latest

	# Do the same for mongo.
	docker pull mongo:4.4.6
	docker tag mongo:4.4.6 localhost:5001/mongo:4.4.6
	docker push localhost:5001/mongo:4.4.6

	echo "running docker build"
	sudo bash ./docker_scripts/build-docker-images.sh
	echo "done with docker build"

	# Build wrk.
	pushd wrk2
		make
	popd
	
	# N.B. assumes the following or equivalent has run on all nodes so all nodes are able to
	# get to the cluster-local image repo via localhost
	#sudo iptables -t nat -A OUTPUT  -p tcp -d localhost --dport 5001 -j DNAT --to 10.10.1.1:5000

	# push hotel reservation images to the local docker registery used by the kind cluster
	for i in `sudo docker image ls | grep localhost:5001 | awk '{print $1}'`; do sudo docker push $i; done

	SESSION="main"
	tmux kill-session -t $SESSION
	tmux new-session -d -s $SESSION
	tmux split-window -h -t $SESSION:0.0
	tmux split-window -v -t $SESSION:0.1
	sleep 10
	tmux send-keys -t $SESSION:0.1 "cd ~/intermesh_universe/intermesh/ && bash scripts/launch_intermesh.sh" Enter

	if [ "$CLUSTERROLE" = "primary" ]; then
		kubectl delete -Rf kubernetes/
		kubectl apply -Rf kubernetes/
		kubectl delete -Rf kubernetes/frontend/
		envsubst < kubernetes/frontend/frontend-deployment.yaml | kubectl apply -f -
		kubectl apply -f kubernetes/frontend/frontend-service.yaml

		tmux send-keys -t $SESSION:0.2 "cd ~/intermesh_universe/intermesh/ && python intermesh/intermesh_ctl.py peer --cluster_domain $REMOTEINTERMESHDDOMAIN"

	else
		kubectl delete -Rf mesh2/
		kubectl apply -Rf mesh2/
	fi

popd

mkdir intermesh_universe
pushd intermesh_universe
	git clone git@github.com:lloydbrownjr/intermesh.git --config core.sshCommand="ssh  -i $INTERMESH_KEY"
	pushd intermesh
		kubectl apply -f ./conf/intermesh.yaml
		pip3 install -r requirements.txt

	popd
popd

# set up tmux for intercluster connection
logtend "intermesh"
touch $OURDIR/intermesh-done
