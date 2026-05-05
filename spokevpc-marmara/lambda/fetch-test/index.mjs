import { promises } from 'node:dns'

export const handler = async (event) => {
  const host = "www.google.com";
  // const host = "imas.gamedbs.jp";
  console.log("resolve hostname", host)
  let addresses6 = await promises.resolve6(host);
  let addresses4 = await promises.resolve4(host);
  console.log("resolved", addresses4, addresses6)
  let url = `https://${host}`;
  // let url = `https://[${addresses[0]}]`;
  let testRes = await fetch(url);
  const response = {
    statusCode: 200,
    body: JSON.stringify({
      resolver: {
        ipv4: addresses4,
        ipv6: addresses6
      },
      fetch: {
        status: testRes.status,
        headers: testRes.headers
      }
    })
  };
  return response;
};
