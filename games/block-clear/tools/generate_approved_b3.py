from pathlib import Path
import os,sys,json,time
ROOT=Path(__file__).resolve().parents[3]/'work/block-clear-runtime/local-tts'
sys.path.insert(0,str(ROOT/'packages'))
os.environ['HF_HUB_OFFLINE']='1'
os.environ['TRANSFORMERS_OFFLINE']='1'
os.environ['NUMBA_CACHE_DIR']=str(ROOT/'numba-cache')
import torch,numpy as np,soundfile as sf,lameenc
from qwen_tts import Qwen3TTSModel
PROJECT=ROOT.parents[2]/'outputs/block-clear'
OUT=PROJECT/'voice-audition/approved-b3'
OUT.mkdir(exist_ok=True)
plan=json.loads((PROJECT/'voice-audition/selected-08/generation-plan.json').read_text(encoding='utf-8'))
torch.set_num_threads(6)
torch.set_num_interop_threads(2)
model=Qwen3TTSModel.from_pretrained(str(ROOT/'base-model'),device_map='cpu',dtype=torch.float32,attn_implementation='sdpa',local_files_only=True)
ref,sr=sf.read(PROJECT/'voice-audition/mandarin-v2/08.mp3',dtype='float32')
if ref.ndim>1:ref=ref.mean(axis=1)
transcript='你说得没错呀，我周末也去看了这部电影，可以称得上是五年内最好的动作片了。'
prompt=model.create_voice_clone_prompt(ref_audio=(ref,round(sr*1.035)),ref_text=transcript,x_vector_only_mode=False)
records=[]
for item in plan['files']:
    dest=OUT/item['filename']
    if not dest.exists():
        start=time.time();torch.manual_seed(808)
        with torch.inference_mode():
            waves,rate=model.generate_voice_clone(text=item['text'],language='Chinese',voice_clone_prompt=prompt,non_streaming_mode=True,max_new_tokens=180,temperature=.6,top_p=.9,subtalker_temperature=.7)
        samples=np.asarray(waves[0],dtype=np.float32)
        if not np.isfinite(samples).all() or len(samples)<rate*.25:raise ValueError('Invalid audio')
        nonquiet=np.flatnonzero(np.abs(samples)>.008)
        if len(nonquiet):samples=samples[max(0,nonquiet[0]-int(rate*.08)):min(len(samples),nonquiet[-1]+int(rate*.16))]
        peak=float(np.max(np.abs(samples)))
        if peak>0:samples*=min(.88/peak,2)
        sf.write(dest.with_suffix('.wav'),samples,rate,subtype='PCM_16')
        enc=lameenc.Encoder();enc.set_bit_rate(96);enc.set_in_sample_rate(rate);enc.set_channels(1);enc.set_quality(2)
        dest.write_bytes(enc.encode((np.clip(samples,-1,1)*32767).astype('<i2').tobytes())+enc.flush())
        print('Generated',dest.name,round(time.time()-start,1),flush=True)
    audio,rate=sf.read(dest.with_suffix('.wav'),dtype='float32')
    records.append({**item,'duration':len(audio)/rate})
    (OUT/'generated.json').write_text(json.dumps({'voice':'approved-B3','model':'Qwen/Qwen3-TTS-12Hz-0.6B-Base','seed':808,'reference_rate_factor':1.035,'output_pitch_processing':False,'files':records},ensure_ascii=False,indent=2),encoding='utf-8')
print('COMPLETE',len(records),flush=True)
