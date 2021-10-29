import plantuml from 'node-plantuml';
import fs from 'fs';
import {readFile, mkdir} from 'fs/promises';

const outputLoc = "./build/";

const myArgs = process.argv.slice(2);

try {
  await mkdir(outputLoc);
} catch {
//  nop if directory doesn't exist
}

for (const arg of myArgs) {
  const path = arg.split("/");
  const fileroot = path[path.length - 1].split(".")[0];

  const docContent = await readFile(arg, "utf8");
  const len = (docContent.match(/newpage/g) || []).length;

  for (var i = 0; i <= len; i++) {
    (function () {
      const j = i;
      const gen = plantuml.generate(docContent, {"pipeimageindex": j});
      const outputFile = outputLoc + fileroot + "-plantuml-image-" + j + ".png";

      console.log("starting:" + outputFile);

      gen.out.pipe(fs.createWriteStream(
          outputFile)).on('finish',
          _ => {
            console.log(arg + ": generated image " + j + " of " + len + " to " + outputFile);
          })
    })();
  }
}