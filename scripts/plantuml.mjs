import plantuml from 'node-plantuml';
import fs from 'fs';
import {readFile, mkdir} from 'fs/promises';

var docLoc = "./docs/flows/flows.puml";
var outputLoc = "./build/";

var docContent = await readFile(docLoc, "utf8");

// console.log(docContent);

try {
  await mkdir(outputLoc);
} catch {
//  nop if directory doesn't exist
};

for (var i = 0; i <= (docContent.match(/newpage/g) || []).length; i++) {
  var gen = plantuml.generate(docContent, { "pipeimageindex": i});
  // console.log(gen);
  gen.out.pipe(fs.createWriteStream(outputLoc + "flows-plantuml-image-"+i+".png"));
}