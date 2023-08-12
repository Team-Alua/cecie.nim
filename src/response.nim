import asyncnet
template respondWith(client: AsyncSocket) =
  await client.send("")

