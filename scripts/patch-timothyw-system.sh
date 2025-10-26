#!/bin/bash

kubectl patch application timothyw-system -n argocd --type=json -p='[{"op":"add","path":"/spec/ignoreDifferences","value":[{"group":"argoproj.io","kind":"Application","jsonPointers":["/spec/source/helm/parameters"]}]}]'
