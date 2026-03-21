// highlight.js/lib/languages/json@11.11.1 downloaded from https://ga.jspm.io/npm:highlight.js@11.11.1/es/languages/json.js

function json(e){const n={className:"attr",begin:/"(\\.|[^\\"\r\n])*"(?=\s*:)/,relevance:1.01};const s={match:/[{}[\],:]/,className:"punctuation",relevance:0};const a=["true","false","null"];const t={scope:"literal",beginKeywords:a.join(" ")};return{name:"JSON",aliases:["jsonc"],keywords:{literal:a},contains:[n,s,e.QUOTE_STRING_MODE,t,e.C_NUMBER_MODE,e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE],illegal:"\\S"}}export{json as default};

