with open('Sources/OracleOS/Events/FileEventStore.swift', 'r') as f:
    text = f.read()

text = text.replace('try handle.synchronize()', 'try handle.synchronize()\n        fsync(handle.fileDescriptor)')

with open('Sources/OracleOS/Events/FileEventStore.swift', 'w') as f:
    f.write(text)
