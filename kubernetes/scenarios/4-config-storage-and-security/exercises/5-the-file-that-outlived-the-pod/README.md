# S4.x5 · The file that outlived the Pod

*Write a file, delete the Pod, and the file is still there. Magic? No, a PersistentVolumeClaim.*

⏱ about 10 min · beginner · PersistentVolumeClaim, volumes, StorageClass, data outliving a Pod

This is a **question exercise**: there is no `break.sh`. You set the scene with the commands below, answer the questions with `kubectl`, then check the answers. Stuck? Open a hint first.

## 📖 The story
A container's own filesystem disappears with the container. For data that has to survive, a Pod asks for storage with a **PersistentVolumeClaim** (a request: "I need 100 MB") and mounts it. The cluster's default StorageClass makes the actual disk.

## 🛠 Set the scene
```bash
kubectl get storageclass
kubectl create namespace ex-4-5
kubectl apply -n ex-4-5 -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: notes
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: writer
spec:
  terminationGracePeriodSeconds: 1
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "echo \"first note: $(date)\" >> /data/notes.txt; sleep 3600"]
      volumeMounts:
        - { name: data, mountPath: /data }
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: notes
EOF
kubectl wait pod/writer -n ex-4-5 --for=condition=Ready --timeout=120s
```

## ❓ Your tasks
1. Look at `kubectl get pvc,pv -n ex-4-5`. What is the PVC's STATUS, and who created the PersistentVolume? (If the status is `Pending` before the Pod, read why.)
2. Read the file: `kubectl exec writer -n ex-4-5 -- cat /data/notes.txt`.
3. Delete the Pod: `kubectl delete pod writer -n ex-4-5`. Start a reader Pod that mounts the same claim and cats the file (copy the YAML above, change the name to `reader` and the command to `cat /data/notes.txt; sleep 3600`).
4. What would have happened to the note if the Pod had used `emptyDir` instead of the claim?

## 💡 Hints
<details><summary>Hint 1</summary>

Some StorageClasses wait for the first Pod before creating the disk (`WaitForFirstConsumer`).

</details>

<details><summary>Hint 2</summary>

`kubectl logs reader -n ex-4-5` shows what `cat` printed.

</details>

## ✅ Answers
<details><summary>Open when you have tried every task</summary>

1. `Bound`. The PersistentVolume was created automatically by the default StorageClass (dynamic provisioning). With `WaitForFirstConsumer` the PVC stays `Pending` until a Pod uses it.
2. It prints `first note: ...` with the time.
3. The reader prints the same `first note` line. The data lives in the volume, not in the Pod.
4. Gone. An `emptyDir` is created with the Pod and deleted with it. Use it for scratch space, never for data you care about.

</details>

## 🧹 Clean up
```bash
kubectl delete namespace ex-4-5
```

← [Section 4: Configuration, storage and security](../../README.md)
