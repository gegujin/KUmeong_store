node "C:\npm-global\node_modules\newman\bin\newman.js" run postman_collection.json `
  --environment environment.json `
  --reporters cli,htmlextra `
  --reporter-htmlextra-export report.html
