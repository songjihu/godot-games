from pathlib import Path
import os,sys,json,time,argparse
ROOT=Path(__file__).resolve().parents[3]/'work/block-clear-runtime/local-tts'
sys.path.insert(0,str(ROOT/'packages'))
os.environ['HF_HUB_OFFLINE']='1'
os.environ['TRANSFORMERS_OFFLINE']='1'
os.environ['NUMBA_CACHE_DIR']=str(ROOT/'numba-cache')
import torch,numpy as np,soundfile as sf,lameenc
from qwen_tts import Qwen3TTSModel

parser=argparse.ArgumentParser()
parser.add_argument('--limit',type=int,default=1)
args=parser.parse_args()
if args.limit > 1:
    raise SystemExit('User approval of the new voice is required before batch generation.')
PROJECT=ROOT.parents[2]/'outputs/block-clear'
plan=json.loads((Path(__file__).with_name('local_voice_plan.json')).read_text(encoding='utf-8'))
OUT=PROJECT/'voice-audition/local-mature'
OUT.mkdir(exist_ok=True)
instruction='一位三十岁左右的成熟女性，标准普通话，音色柔美温润，中低音域，有沉稳自信的姐姐气质。说话自然、亲切、从容，带淡淡的笑意和温柔鼓励。不要儿童或少女感，不要夹子音，不要撒娇，不要播音腔，不夸张，不耳语。语速适中，每句话轻柔收尾。'
torch.set_num_threads(6)
torch.set_num_interop_threads(2)
device='cuda:0' if torch.cuda.is_available() else 'cpu'
dtype=torch.bfloat16 if device.startswith('cuda') else torch.float32
print('Loading local voice-design model:',device,dtype,flush=True)
model=Qwen3TTSModel.from_pretrained(str(ROOT/'model'),device_map=device,dtype=dtype,attn_implementation='sdpa',local_files_only=True)
print('Local model ready',flush=True)
records=json.loads((OUT/'generated.json').read_text(encoding='utf-8'))['files'] if (OUT/'generated.json').exists() else []
for item in plan['files'][:args.limit]:
    dest=OUT/item['filename']
    if dest.exists():
        print('Already generated:',dest.name,flush=True)
        continue
    torch.manual_seed(708)
    start=time.time()
    with torch.inference_mode():
        waves,rate=model.generate_voice_design(text=item['text'],language='Chinese',instruct=instruction,max_new_tokens=160,temperature=0.65,top_p=0.9,subtalker_temperature=0.7)
    samples=np.asarray(waves[0],dtype=np.float32)
    if not np.isfinite(samples).all() or len(samples)<rate*.25:raise ValueError('Invalid audio')
    # Remove only near-silent margins; retain natural pauses inside each sentence.
    nonquiet=np.flatnonzero(np.abs(samples)>.008)
    if len(nonquiet):samples=samples[max(0,nonquiet[0]-int(rate*.08)):min(len(samples),nonquiet[-1]+int(rate*.16))]
    peak=float(np.max(np.abs(samples)))
    if peak>0:samples=samples*min(0.88/peak,2.0)
    sf.write(OUT/(dest.stem+'.wav'),samples,rate,subtype='PCM_16')
    encoder=lameenc.Encoder()
    encoder.set_bit_rate(96);encoder.set_in_sample_rate(rate);encoder.set_channels(1);encoder.set_quality(2)
    pcm=(np.clip(samples,-1,1)*32767).astype('<i2').tobytes()
    dest.write_bytes(encoder.encode(pcm)+encoder.flush())
    record={**item,'duration':len(samples)/rate,'generation_seconds':round(time.time()-start,2)}
    records.append(record)
    (OUT/'generated.json').write_text(json.dumps({'model':'Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign','mode':'local','original_voice':True,'not_identical_to_platform_08':True,'instruction':instruction,'seed':708,'files':records},ensure_ascii=False,indent=2),encoding='utf-8')
    print('Generated:',dest.name,record['duration'],'seconds, generation',record['generation_seconds'],flush=True)
print('Finished local generation',flush=True)
