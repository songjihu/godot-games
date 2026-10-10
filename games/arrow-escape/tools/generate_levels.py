import random,json
from pathlib import Path
D=[(1,0),(-1,0),(0,1),(0,-1)]
def make(seed,w,h,count):
 r=random.Random(seed);paths=[];occupied=set()
 for attempt in range(30000):
  if len(paths)>=count:break
  start=(r.randrange(w),r.randrange(h))
  if start in occupied:continue
  p=[start]
  for _ in range(r.randrange(1,6)):
   options=[(p[-1][0]+dx,p[-1][1]+dy) for dx,dy in D]
   options=[q for q in options if 0<=q[0]<w and 0<=q[1]<h and q not in occupied and q not in p]
   if not options:break
   p.append(r.choice(options))
  if len(p)<2:continue
  dx,dy=p[-1][0]-p[-2][0],p[-1][1]-p[-2][1]
  x,y=p[-1][0]+dx,p[-1][1]+dy
  clear=True
  while 0<=x<w and 0<=y<h:
   if (x,y) in occupied:clear=False;break
   x+=dx;y+=dy
  if not clear:continue
  paths.append(p);occupied.update(p)
 return {'width':w,'height':h,'paths':paths}
def generate():
 levels=[]
 first=[(5,6,5),(6,7,8),(6,8,10),(7,9,13),(7,9,15),(8,10,18),(8,11,20),(9,11,24),(9,12,27),(10,12,30)]
 first_names=['初见清风','一径通幽','曲水回环','交错之间','拨云见路','从容落笔','疏影横斜','千回百转','心有清境','自在归途']
 for i,(w,h,n) in enumerate(first):
  level=make(1211+i*37,w,h,n);level['name']=first_names[i];levels.append(level)
 shapes=[(7, 9, 14), (7, 9, 16), (8, 10, 18), (8, 10, 17), (8, 10, 20), (8, 11, 21), (9, 11, 22), (9, 12, 24), (9, 12, 25), (10, 12, 27)]
 names=['雾起渡口', '水下回声', '解缚归流', '一叶无舟', '灯影摇红', '旧人倒影', '未燃之灯', '桨声深处', '此岸彼岸', '渡河之问']
 for i,(w,h,n) in enumerate(shapes):
  level=make(202611+i*47,w,h,n);level['name']=names[i];levels.append(level)
 return levels

if __name__=='__main__':
 levels=generate()
 Path(__file__).resolve().parents[1].joinpath('levels/campaign.json').write_text(json.dumps(levels,ensure_ascii=False,indent=2),encoding='utf-8')
 print('Generated',len(levels),'solvable levels')
