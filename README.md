### Install some of my most common configurations for linux using Ansible. 
- Python
- Nvidia Driver
- Docker
#### 0. Update ```config/inventory``` File
*See example. Will need hostname, IP and user*
#### 1. Management Node Setup
```bash
scripts/setup.sh
```

#### 2. Remote Node Setup
```bash
ansible-playbook playbooks/mlops.yml -k -K -v
```
