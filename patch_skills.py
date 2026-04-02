import os
import glob
import re

skill_dir = 'Sources/OracleOS/Code/Skills'
skills = glob.glob(os.path.join(skill_dir, '*.swift'))

for skill in skills:
    with open(skill, 'r') as f:
        content = f.read()
    
    # We want to replace CodeSkillSupport.command with the direct inline initialization of the corresponding Typed payload!
    # Wait, some skills are git, some are file mutation, some are code action.
    # It might be easier to just change CodeSkillSupport.command to return a CommandPayload! Let's do that instead of touching all files!
