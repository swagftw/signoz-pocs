FROM python:3.9-alpine

CMD ["python", "-u", "-c", "import time; n=0\nwhile True: print(f'hello world {n}', flush=True); n+=1; time.sleep(5)"]