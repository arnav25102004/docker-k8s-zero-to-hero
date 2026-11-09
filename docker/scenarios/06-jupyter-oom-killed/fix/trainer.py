# A toy "AI trainer": five epochs, and each epoch loads another 150 MB of data.
import time

data = []
for epoch in range(1, 6):
    print(f"epoch {epoch}/5 ... loading 150 MB", flush=True)
    data.append(bytearray(b"x") * (150 * 1024 * 1024))
    time.sleep(1)
print("model trained", flush=True)
