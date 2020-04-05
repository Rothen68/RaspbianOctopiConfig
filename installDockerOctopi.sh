#!/bin/bash
Env="prod"

RED='\033[0;31m'
GREEN='\033[0;32m'
GREENB='\033[1;32m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

#server IP
ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | tr -d '\r')

function installCAdvisor
{
	if [ "$Env" = "test" ]
	then
		installCAdvisorTest
	else
		installCAdvisorProd
	fi
}


function installCAdvisorTest
{
	printf "\n\n"
	read -p "Which port do you want to use for this container [8080] ? " port
	port="${port:=8080}"
	read -p "Which name do you want to use for this container [cadvisor] ? " name 
	name="${name:=cadvisor}"

	printf "CAdvisor will be named $name and will use the port $port\n"

	VERSION=v0.36.0 # use the latest release version from https://github.com/google/cadvisor/releases

	printf " $name:
  image: gcr.io/google-containers/cadvisor:$VERSION
  ports:
   - $port:8080
  volumes:
   - /:/rootfs:ro
   - /var/run:/var/run:ro
   - /sys:/sys:ro
   - /var/lib/docker/:/var/lib/docker:ro
   - /dev/disk/:/dev/disk:ro\n">>$dockercompose

	  
}

function installCAdvisorProd
{
	printf "\n\n"
	read -p "Which port do you want to use for this container [8080] ? " port
	port="${port:=8080}"
	read -p "Which name do you want to use for this container [cadvisor] ? " name 
	name="${name:=cadvisor}"

	printf "CAdvisor will be named $name and will use the port $port\n"

	echo "Image source : 
	  - Build locally by downloading the latest CAdvisor version
	  - Use the version from budry/cadvisor-arm

	  "

	read -p "Do you want to build the container locally [n] ? " buildLocally
	buildLocally="${buildLocally:=n}"

	if [ "$buildLocally" = "y" ]
	then
		git clone https://github.com/Budry/cadvisor-arm.git
		cd cadvisor-arm
		docker build -t cadvisor/cadvisor .
		imageName="cadvisor/cadvisor"
		cd ..
		rm -r -f cadvisor-arm
	else
		docker pull budry/cadvisor-arm
		imageName="budry/cadvisor-arm"
	fi

	VERSION=v0.36.0 # use the latest release version from https://github.com/google/cadvisor/releases

	printf " $name:
  image: $imageName
  ports:
   - $port:8080
  volumes:
   - /:/rootfs:ro
   - /var/run:/var/run:ro
   - /sys:/sys:ro
   - /var/lib/docker/:/var/lib/docker:ro
   - /dev/disk/:/dev/disk:ro\n\n">>$dockercompose

}


function installOctoprint
{

	docker pull octoprint/octoprint
	imageName="octoprint/octoprint"

	usb0=$(ls /dev | grep ttyUSB0)
	usb1=$(ls /dev | grep ttyUSB1)
	usb2=$(ls /dev | grep ttyUSB2)
	usb3=$(ls /dev | grep ttyUSB3)
	ama0=$(ls /dev | grep ttyAMA0)
	ama1=$(ls /dev | grep ttyAMA1)
	ama2=$(ls /dev | grep ttyAMA2)
	ama3=$(ls /dev | grep ttyAMA3)

	ports=""
	if [ "$usb0" = "ttyUSB0" ]
	then
	      ports="${ports}   - /dev/ttyUSB0:/dev/ttyUSB0\n"
	fi
	if [ "$usb1" = "ttyUSB1" ]
	then
	      ports="${ports}   - /dev/ttyUSB1:/dev/ttyUSB1\n"
	fi
	if [ "$usb2" = "ttyUSB2" ]
	then
	      ports="${ports}   - /dev/ttyUSB2:/dev/ttyUSB2\n"
	fi
	if [ "$usb3" = "ttyUSB3" ]
	then
	      ports="${ports}   - /dev/ttyUSB3:/dev/ttyUSB3\n"
	fi
	if [ "$ama0" = "ttyAMA0" ]
	then
	      ports="${ports}   - /dev/ttyAMA0:/dev/ttyAMA0\n"
	fi
	if [ "$ama1" = "ttyAMA1" ]
	then
	      ports="${ports}   - /dev/ttyAMA1:/dev/ttyAMA1\n"
	fi
	if [ "$ama2" = "ttyAMA2" ]
	then
	      ports="${ports}   - /dev/ttyAMA2:/dev/ttyAMA2\n"
	fi
	if [ "$ama3" = "ttyAMA3" ]
	then
	      ports="${ports}   - /dev/ttyAMA3:/dev/ttyAMA3\n"
	fi

	printf "${ORANGE}Printer port searching : \n"
	printf "${ports}"
	printf "These ports will be mounted inside each octoprint installation, you will have to select the correct one for each printer.${NC}\n"

	configure="y"
	let "nbr = 0"
	volumes=""
	while [ "$configure" = "y" ]
	do
		let "nbr = nbr + 1 "
		printf "Octoprint configuration : Instance $nbr\n"
		read -p "Name of the instance [Octoprint$nbr] ? " instanceName
		instanceName="${instanceName:=Octoprint$nbr}"
		let "defaultPort = 4999 + nbr "
		read -p "Which port do you want to use for this container [$defaultPort] ? " port
		port="${port:=$defaultPort}"



		printf " $instanceName:
  image: $imageName
  ports:
   - $port:5000
  volumes:
   - $instanceName:/home/octoprint
  devices:
$ports\n\n">>$dockercompose

		volumes="${volumes}  $instanceName:\n"

		printf "Instance $nbr configured\n\n"

		read -p "Do you want to configure another instance (n) ? " configure
		configure="${configure:=n}"
	done

	printf "volumes:
$volumes\n">>$dockercompose

}




printf "${GREENB}------Docker installation------${NC}\n"
read -p "What is your username ? " username

dockerInstallSteps="5"

printf "${ORANGE}1/$dockerInstallSteps : Remove previous installation${NC}\n"
sudo apt-get remove docker docker-engine docker.io containerd runc

printf "${ORANGE}2/$dockerInstallSteps : Package configuration${NC}\n"
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -y
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
if [ "$Env" = "test" ]
then
	sudo add-apt-repository \
	   "deb [arch=amd64] https://download.docker.com/linux/debian \
	   $(lsb_release -cs) \
	   stable"
else
	sudo add-apt-repository \
   "deb [arch=arm64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
fi

printf "${ORANGE}3/$dockerInstallSteps : Installation de Docker Engine${NC}\n"
sudo apt-get update && apt-get install docker-ce docker-ce-cli containerd.io net-tools git -y

printf "${ORANGE}4/$dockerInstallSteps : Ajout de l'utilisateur $username au groupe Docker${NC}\n"
sudo usermod -a -G docker $username

printf "${ORANGE}5/$dockerInstallSteps : Test de Docker${NC}\n"
dockerResult=$(docker run hello-world | grep "Hello from Docker!")
if [ "$dockerResult" = 'Hello from Docker!' ]
then

	printf "${GREEN}------Docker installed------${NC}\n"
else
	printf "${RED}Error during docker installation${NC}\n"
fi


printf "${GREENB}------Containers setup------${NC}\n"
dockercompose="docker-compose.yml"
rm docker-compose.yml
printf "version: '3.7'\n\nservices:\n" >>$dockercompose

printf "${ORANGE} - CAdvisor ${NC}\n"
printf "Analyzes resource usage and performance characteristics of the system and the running containers.\n\n"
read -p "Do you want to use CAdvisor [y]? (y/n)"  install
install="${install:=y}"
if [ "$install" = "y" ]
then
	installCAdvisor
fi

printf "${ORANGE} - Octoprint ${NC}\n"
read -p "Do you want to install Octoprint [y]? (y/n)"  install
install="${install:=y}"
if [ "$install" = "y" ]
then
	installOctoprint
fi

docker-compose up -d

