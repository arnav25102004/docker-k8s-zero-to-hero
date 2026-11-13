# S3.x2 · Who is behind the Service?

*Take one Pod out of the Service without deleting it. The quarantine trick every on-call engineer knows.*

⏱ about 10 min · intermediate · EndpointSlices, label selectors, isolating a Pod for debugging

This is a **question exercise**: there is no `break/run.py`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
A Service has no list of Pods. It has a **selector**, and Kubernetes keeps a list of matching, Ready Pod IPs (EndpointSlices). Change one Pod's label and it drops out of that list instantly, but the Pod keeps running, so you can poke at it. This is how you debug a misbehaving Pod without losing the evidence.

## 🛠 Set the scene
```bash
kubectl create namespace ex-3-2
kubectl create deployment web -n ex-3-2 --image=hashicorp/http-echo:1.0.0 --replicas=3 -- /http-echo -text="web"
kubectl expose deployment web -n ex-3-2 --port=80 --target-port=5678
kubectl rollout status deployment/web -n ex-3-2 --timeout=120s
```

## ❓ Your tasks
1. List the Service's endpoints: `kubectl get endpointslices -n ex-3-2 -l kubernetes.io/service-name=web`. Compare the IPs with `kubectl get pods -n ex-3-2 -o wide`.
2. Pick one Pod and change its label: `kubectl label pod <pod-name> -n ex-3-2 app=web-suspect --overwrite`. Count the Pods now (`kubectl get pods -n ex-3-2 --show-labels`). Why are there four?
3. Check the endpoints again. How many addresses does the Service send traffic to?
4. The suspect Pod is still running. How would you look inside it without any user ever reaching it?

## 💡 Hints
<details><summary>Hint 1</summary>

The Service selector is `app=web`. So is the ReplicaSet's.

</details>

<details><summary>Hint 2</summary>

The ReplicaSet counts Pods that match its selector.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. Three addresses, one per Pod IP.
2. The relabelled Pod no longer matches the ReplicaSet's selector, so the ReplicaSet thinks one Pod is missing and creates a new one. The suspect is now an unmanaged extra Pod: four in total.
3. Three again: the two untouched Pods and the new one. The suspect is out.
4. `kubectl exec -it <suspect> -n ex-3-2 -- sh` and `kubectl logs <suspect> -n ex-3-2`. Nobody else hits it. Delete it when you are done.

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-3-2
```

← [Section 3: Services, ingress and networking](../../README.md)
