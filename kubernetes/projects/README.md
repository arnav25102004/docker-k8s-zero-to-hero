# 🏁 The two projects: build them with us, then build your own

These are the **lab exercises 5 and 6** of the syllabus, written as two complete, end-to-end projects. Each one is meant to end up on your GitHub and on your CV. We build the reference version together in class. **You then build your own version with your own idea.** Our versions are the guide you check yourself against.

| | Project 1 · Canteen Rush | Project 2 · Canteen Rush, packaged |
|---|---|---|
| **Lab exercise** | 5: deploy containerised applications, configure Deployments, Services, scaling and rolling updates | 6: create Jobs and CronJobs, manage configuration with ConfigMaps and Secrets, deploy applications using Helm |
| **You build** | a containerised ordering app, deployed, scaled under load, updated with no downtime, rolled back when bad | a menu you can change live, a rotatable secret, a one-time Job, a nightly CronJob, and a Helm chart with dev and prod values |
| **The big moment** | version 2 ships while customers are ordering, and not one request fails | the nightly job closes the day by itself, and one `helm rollback` undoes a bad upgrade |
| **Guide** | [Project 1](project-1-canteen-rush/README.md) | [Project 2](project-2-canteen-helm/README.md) |
| **Time** | about 2.5 hours (45-minute live path) | about 2.5 hours (50-minute live path) |

## The app
Both projects use one small ordering app, [`apps/canteen`](../../apps/canteen): Python standard library only, so there is nothing to install and nothing to distract from the platform. Every response says **which counter (Pod) served it**, orders live in memory or Redis, there is a **crash** button and a **CPU burner**, the menu can come from a ConfigMap file, and "close the day" is protected by a token. Each feature exists to make one Kubernetes idea visible.

## How to use them
1. **Watch and follow along** in class, one phase at a time. Every phase ends with a "Done when" check and, where it matters, an 📸 evidence item.
2. **Build your own** version: pick a different idea (a hostel mess, a library seat tracker, a gym slot booker) and keep the same *contract* (the project guides list it).
3. **Mark yourself** with the rubric at the bottom of each guide, out of 20. A mentor can use the same one.
4. **Publish it**: each guide ends with a README template, resume bullets and the interview questions the project prepares you for.

## Before either project
```bash
./scripts/install-metrics-server.sh                      # kubectl top, and the autoscaler
docker build -t canteen-rush:1.0.0 apps/canteen
docker build -t canteen-rush:2.0.0 --build-arg VERSION=2.0.0 apps/canteen
./scripts/load-image.sh canteen-rush:1.0.0 canteen-rush:2.0.0
```
Project 2 also needs [`helm`](../README.md).

Want a CI/CD and monitoring bonus on top? Lab [K20](../20-projects/README.md) deploys with Jenkins and emails you when it breaks.
