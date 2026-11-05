#!/usr/bin/env node
const fs = require("node:fs");
const path = require("node:path");
const data = JSON.parse(fs.readFileSync(path.join(__dirname, "data.json"), "utf8"));
if (data.message !== "sibling data.") throw new Error("Unexpected sibling data");
console.log(data.message);
