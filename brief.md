I want to create a supplementary material about running kubernetes with scaling (not at scale, which is not possible to run on a laptop/pc at best)

this material should have the following components, coupled with documentations
    
    - kubernetes in docker setup, KinD
    - a lightweight sample api server on a docker container
        - will be added in the `deployment` kubernetes definition
    - horizontal scaling, vertical scaling definitions
    - kubernetes metrics server for horizontal pod scaling
    - kubernetes service definitions for api server accessibility
    - load testing tool to simulate synthetic load, to trigger scaling


the setup can be scaffolded and destroyed using automation tooling, like bash scripts


What are the non-negotiable constraints for this supplementary material?  
Think in buckets:
- hardware/runtime limits (CPU, RAM, laptop OS constraints)
    - can run on an 2GB RAM at least
- tooling limits (KinD, Docker Desktop/engine nuances)
    - should be able to run on top of docker only, do not introduce random tools/platform
- learning limits (what not to overcomplicate for readers)
    - HPA, VPA, Deployments, Services, simplify these definitions
- reproducibility limits (what must run with minimal setup friction)
    - we should be able to scaffold and run using the following tools
        - bash, node, docker, KinD


1) Single-node KinD only  H
2) NodePort-only service exposure H  
3) Keep sample API single endpoint  F 
4) Include VPA in “observe-only” mode first F  
5) Require Linux + macOS support in v1 H
6) Load test tool runs as pod (not host binary) F  
7) Full setup under 10 minutes on clean machine  F
8) No internet required after initial image pull F


1) HPA works when: it creates more replicas under load
2) Browser reachability works when: the api server is usable by browser under load
3) Scaffolding/provisioning works when: it creates the entire kubernetes cluster and kubernetes configuraion without hiccups


1) Cluster Bootstrap  
2) Sample API Shape, can be a simplified landing page instead of an API
3) Scaling Policy, only the maximum limit of replicas is flexible here
4) Metrics/Observability Checks  
5) Service Exposure/Access  
6) Load Generation Mode, can be done outside a pod for better simulation
7) Automation Lifecycle, I prefer bash easier to digest than using another tool like opentofu


1) tiny maxReplicas = 5  
2) balanced maxReplicas = 7  
3) stretch maxReplicas = 10