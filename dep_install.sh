#!/bin/bash

#npm install hexo-server --save
#npm install hexo-generator-index --save
#npm install hexo-generator-archive --save
#npm install hexo-generator-category --save
#npm install hexo-generator-tag --save
#npm install hexo-server --save
#npm install hexo-deployer-git --save
#npm install hexo-renderer-marked@0.2 --save
#npm install hexo-renderer-stylus@0.2 --save
#npm install hexo-generator-sitemap@1 --save

npm rebuild hexo
rm -rf node_modules
npm i --no-optional
