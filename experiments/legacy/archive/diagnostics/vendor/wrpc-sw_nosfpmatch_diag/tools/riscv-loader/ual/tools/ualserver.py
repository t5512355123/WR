from PyUALUtils.remote import UALLocal
import xmlrpc.server
import xmlrpc.client
import argparse

def main():
    parser = argparse.ArgumentParser(description='UAL remote server')
    parser.add_argument('-p', '--port', type=int, default=8000,
                        help='local TCP port')
    parser.add_argument('--log', action='store_true', default=False,
                        help='enable log')
    # parser.add_argument('-r', '--remote', help='url of the remote server')

    args = parser.parse_args()

    xmlrpc.client.Marshaller.dispatch[int] = \
        lambda _, v, w: w("<value><i8>%d</i8></value>" % v)

    server = xmlrpc.server.SimpleXMLRPCServer(
        ("", args.port), logRequests=args.log, allow_none=True)

    my_ual = UALLocal()
    server.register_instance(my_ual)

    print("Listening on port {}...".format(args.port))
    server.serve_forever()


if __name__ == "__main__":
    main()
