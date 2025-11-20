#!/bin/bash
newman run tests/postman_collection.json \
  --environment tests/environment.json \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export tests/report.html
