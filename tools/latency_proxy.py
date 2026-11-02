"""Loopback TCP delay/jitter fixture; preserves byte order, never touches public traffic."""
import argparse
import asyncio
import random
import time

async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--listen', type=int, default=18894)
    parser.add_argument('--target', type=int, default=18891)
    parser.add_argument('--delay-ms', type=int, default=150)
    parser.add_argument('--jitter-ms', type=int, default=40)
    parser.add_argument('--stall-after', type=float, default=0)
    parser.add_argument('--stall-ms', type=int, default=0)
    args = parser.parse_args()
    rng = random.Random(31)
    async def connection(reader, writer):
        started=time.monotonic()
        remote_reader, remote_writer = await asyncio.open_connection('127.0.0.1', args.target)
        async def pipe(source, destination):
            queue = asyncio.Queue(maxsize=256)
            async def receive():
                previous = 0
                while True:
                    data = await source.read(65536)
                    if not data:
                        await queue.put((0, b'')); break
                    deadline = max(previous, time.monotonic() + max(0, args.delay_ms + rng.randint(-args.jitter_ms, args.jitter_ms))/1000)
                    if args.stall_after and args.stall_after <= time.monotonic()-started < args.stall_after+args.stall_ms/1000:
                        deadline=max(deadline,started+args.stall_after+args.stall_ms/1000)
                    previous = deadline
                    await queue.put((deadline, data))
            async def transmit():
                while True:
                    deadline, data = await queue.get()
                    if not data:break
                    await asyncio.sleep(max(0, deadline-time.monotonic()))
                    destination.write(data);await destination.drain()
                destination.close()
            await asyncio.gather(receive(), transmit())
        try:await asyncio.gather(pipe(reader, remote_writer), pipe(remote_reader, writer))
        except (ConnectionError, asyncio.CancelledError):pass
        finally:writer.close();remote_writer.close()
    server = await asyncio.start_server(connection, '127.0.0.1', args.listen)
    print(f'Latency fixture ready: {args.delay_ms}ms each direction, ±{args.jitter_ms}ms jitter',flush=True)
    async with server:await server.serve_forever()

if __name__ == '__main__':asyncio.run(main())
