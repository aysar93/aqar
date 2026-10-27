'use strict';
// Process-scoped egress guard for local Node emulator/client processes.
const net = require('node:net'), dns = require('node:dns');
const os = require('node:os');
const ownAddresses = new Set(['0.0.0.0', os.hostname(),
  ...Object.values(os.networkInterfaces()).flat().filter(Boolean).map(i => i.address)]);
const loopbackDestination = host => ownAddresses.has(host) ? '127.0.0.1' : host;
const allowed = h => ['localhost','127.0.0.1','::1','[::1]'].includes(String(h));
const localPipe = value => ['\\\\.\\pipe\\','\\\\?\\pipe\\'].some(prefix=>String(value).startsWith(prefix));
const deny = host => {
  // Hostname only; never URL, headers, payload, or credential values.
  process.stderr.write(JSON.stringify({event:'local_egress_blocked',host:String(host || 'unknown')})+'\n');
  throw Error('LOCAL_TEST_NON_LOOPBACK_BLOCKED');
};
const connect = net.Socket.prototype.connect;
net.Socket.prototype.connect = function (...args) {
  const first = args[0];
  const opts = Array.isArray(first) ? first[0] : first;
  if (typeof opts === 'object' && opts !== null) {
    // Firebase CLI discovers its local worker using an unspecified bind address.
    // Rewrite that connect destination to loopback; never permit a remote host.
    if (opts.host) opts.host = loopbackDestination(opts.host);
    if (opts.hostname) opts.hostname = loopbackDestination(opts.hostname);
    if (opts.path) { if (!localPipe(opts.path)) deny(); }
    else if (!allowed(opts.host || opts.hostname || 'localhost')) deny(opts.host || opts.hostname);
  } else if (typeof opts === 'number') {
    if (typeof args[1] === 'string') args[1] = loopbackDestination(args[1]);
    if (typeof args[1] === 'string' && !allowed(args[1])) deny(args[1]);
  } else if (typeof opts === 'string' && !localPipe(opts)) deny();
  return connect.apply(this, args);
};
const lookup = dns.lookup;
dns.lookup = function (hostname, ...rest) {
  hostname = loopbackDestination(hostname);
  if (!allowed(hostname)) deny(hostname);
  return lookup.call(this, hostname, ...rest);
};
if (globalThis.fetch) {
  const fetch = globalThis.fetch;
  globalThis.fetch = function (input, init) {
    const url = new URL(typeof input === 'string' || input instanceof URL ? input : input.url);
    if (ownAddresses.has(url.hostname)) {
      if (typeof input !== 'string' && !(input instanceof URL)) deny(url.hostname);
      url.hostname = '127.0.0.1';
      input = url;
    }
    if (!allowed(url.hostname)) deny(url.hostname);
    return fetch(input, init);
  };
}
