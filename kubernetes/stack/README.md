# The Showdown stack (shared by labs K04–K13)

| File | What it is |
|---|---|
| [`frontend.yaml`](frontend.yaml) | nginx reverse proxy (Deployment + Service `frontend:80`) that forwards everything to the Service `api:8080` |
| [`redis.yaml`](redis.yaml) | Redis for vote storage (Deployment + Service `redis:6379`) |

Each lab provides its own `api` Deployment + Service, which is the part that lab is about.

Open the UI from any lab:
```bash
kubectl port-forward svc/frontend 8080:80
# → http://localhost:8080
```
📱 To let a room full of people vote from their phones on the same Wi-Fi:
```bash
kubectl port-forward --address 0.0.0.0 svc/frontend 8080:80
# share http://<your-laptop-ip>:8080   (macOS: ipconfig getifaddr en0)
```
⚠️ `--address 0.0.0.0` opens the app to everyone on the same network. Use it only on a network you trust, and press Ctrl+C when the demo is over. (On a playground such as Killercoda or iximiuz, `--address 0.0.0.0` is how the platform's port link reaches it.)
