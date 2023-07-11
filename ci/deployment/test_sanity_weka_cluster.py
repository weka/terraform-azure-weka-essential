import os
import json
import time

from weka_rest_api_client.api import API
from weka_rest_api_client.errors import NoAvailableHosts, BadGatewayError, RestClientError


def parse_ips_from_tf_output():
    output = os.getenv('TF_OUTPUT')
    ips = json.loads(output)['weka_deployment_output']['value']['backend_ips']
    print("IPs -> {}\n".format(ips))
    return ips


def wait_for_cluster_up(wait_mins=15):
    total_sleep = 0
    sleep_time = 10

    while total_sleep < wait_mins * 60:
        try:
            response = api.auth.login(os.getenv('WEKA_USERNAME'), os.getenv('WEKA_PASSWORD'))
            print(f"Auth response: {response}")
            break
        except (NoAvailableHosts, BadGatewayError, RestClientError):
            time.sleep(sleep_time)
            total_sleep += sleep_time

    assert total_sleep < wait_mins * 60, f"There weren't available hosts up during {wait_mins} minutes"


# cluster up waiting section
def validate_cluster_init_stats(wait_mins=15, expected_drives=6, expected_containers=18, expected_processes=36):
    total_sleep = 0
    sleep_time = 10
    cluster = None

    # It looks like drives activity is tha last event happened on cluster up
    # That's why I deside to wait for active drives are set up before proceed with other assertions
    while total_sleep < wait_mins * 60:
        cluster = api.cluster.get.raw().get('data')
        print(f"Total active drivers wait time: {total_sleep}")
        print(f"Cluster response: {cluster}")
        if cluster['drives']['active'] == expected_drives:
            break
        time.sleep(sleep_time)
        total_sleep += sleep_time

    # drives
    assert cluster['drives']['total'] == expected_drives, f"Actual total drives: {cluster['drives']['total']}, " \
                                                          f"Expected: {expected_drives}"
    assert cluster['drives']['active'] == expected_drives, f"Actual active drives: {cluster['drives']['active']}, " \
                                                           f"Expected: {expected_drives}"
    # containers
    assert cluster['io_nodes']['total'] == expected_containers, f"Actual total containers: " \
                                                                f"{cluster['io_nodes']['total']}, " \
                                                                f"Expected: {expected_containers}"
    assert cluster['io_nodes']['active'] == expected_containers, f"Actual active containers: " \
                                                                 f"{cluster['io_nodes']['active']}, " \
                                                                 f"Expected: {expected_containers}"
    # processes
    assert cluster['nodes']['total'] == expected_processes, f"Actual total processes: {cluster['nodes']['total']}, " \
                                                            f"Expected: {expected_processes}"
    assert cluster['nodes']['blacklisted'] == 0, f"Actual blacklisted processes: {cluster['nodes']['blacklisted']}, " \
                                                 f"Expected: 0"


if __name__ == '__main__':
    print('SANITY TEST WAS STARTED')
    api = API(parse_ips_from_tf_output())
    wait_for_cluster_up()
    validate_cluster_init_stats()
    print('SANITY TEST WAS FINISHED')
