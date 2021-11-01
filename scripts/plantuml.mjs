import plantuml from 'node-plantuml';
import fs from 'fs';
import {readFile, mkdir} from 'fs/promises';
import path from 'path';

const myArgs = process.argv.slice(2);

for (const arg of myArgs) {
  const pathObj = path.parse(arg);

  const docContent = await readFile(arg, "utf8");
  const len = (docContent.match(/newpage/g) || []).length;

  const targetDir = pathObj.dir + path.sep + 'images' + path.sep + pathObj.name
      + path.sep;

  try {
    await mkdir(targetDir, {recursive: true});
  } catch (err) {
//  nop if directory doesn't exist
  }

  for (var i = 0; i <= len; i++) {
    (function () {
      const j = i;
      const gen = plantuml.generate(docContent, {"pipeimageindex": j});

      const outputFile = targetDir + pathObj.base + "-plantuml-image-" + j
          + ".png";

      console.log("starting:" + outputFile);

      gen.out.pipe(fs.createWriteStream(
          outputFile)).on('finish',
          _ => {
            console.log(arg + ": generated image " + j + " of " + len + " to "
                + outputFile);
          })
    })();
  }
}