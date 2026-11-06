"""Rebuild sample metadata for published files by walking the lineage graph.

Hop 1: published file  -> `source` (the task output in work/)
Hop 2: task output     -> TaskRun (strip the filename from the LID)
Hop 3: TaskRun inputs  -> the `meta` map that went into the task
"""
import csv, json, subprocess, sys

def view(lid):
    out = subprocess.run(['nextflow', 'lineage', 'view', lid], capture_output=True, text=True, check=True).stdout
    return json.loads(out[out.index('{'):])

run_lid = subprocess.run(['nextflow', 'lineage', 'list'], capture_output=True, text=True, check=True) \
    .stdout.strip().splitlines()[-1].split()[-1]
published = subprocess.run(['nextflow', 'lineage', 'find', f'workflowRun={run_lid}', 'type=FileOutput'],
                           capture_output=True, text=True, check=True).stdout.split()

writer = csv.writer(sys.stdout)
writer.writerow(['id', 'patient', 'tissue', 'process', 'path'])
for lid in published:
    if not lid.startswith(run_lid + '/'):
        continue  # task outputs in work/, only published files wanted
    file_out = view(lid)['spec']
    task = view(file_out['source'].rsplit('/', 1)[0])['spec']
    meta = next(i['value'] for i in task['input'] if i['name'] == 'meta')
    writer.writerow([meta['id'], meta['patient'], meta['tissue'], task['name'], file_out['path']])
