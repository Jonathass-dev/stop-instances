import os
from google.cloud import asset_v1, compute_v1, container_v1
import functions_framework

FOLDER_ID = os.environ.get("FOLDER_ID")
DRY_RUN = os.environ.get("DRY_RUN", "false").lower() in ("true", "1", "yes")


def execute_finops_shutdown():
    """Discover and stop all GCE instances and scale down GKE clusters in a single pass."""
    if not FOLDER_ID:
        raise ValueError("Environment variable 'FOLDER_ID' is required but not set.")

    parent_scope = f"folders/{FOLDER_ID}"
    tag = "DRY-RUN" if DRY_RUN else "EXECUTING"
    print(f"[{tag}] Starting Weekend FinOps shutdown for scope: {parent_scope}", flush=True)

    asset_client = asset_v1.AssetServiceClient()
    instances_client = compute_v1.InstancesClient()
    cluster_client = container_v1.ClusterManagerClient()

    # Single high-performance search for both GCE and GKE
    request = asset_v1.SearchAllResourcesRequest(
        scope=parent_scope,
        asset_types=[
            "compute.googleapis.com/Instance",
            "container.googleapis.com/Cluster"
        ],
    )

    gce_stopped = 0
    gke_scaled = 0

    for resource in asset_client.search_all_resources(request=request):
        parts = resource.name.split("/")
        asset_type = resource.asset_type

        # 1. Process GCE Instances
        if asset_type == "compute.googleapis.com/Instance":
            project_id, zone, instance_name = parts[4], parts[6], parts[8]
            try:
                instance = instances_client.get(project=project_id, zone=zone, instance=instance_name)
                if instance.status == "RUNNING":
                    tag = "DRY-RUN" if DRY_RUN else "EXECUTING"
                    print(f"[{tag}] Stopping VM '{instance_name}' in project '{project_id}' (Zone: {zone})", flush=True)
                    if not DRY_RUN:
                        instances_client.stop(project=project_id, zone=zone, instance=instance_name)
                    gce_stopped += 1
                else:
                    print(f"[SKIP] VM '{instance_name}' in project '{project_id}' is {instance.status}", flush=True)
            except Exception as e:
                print(f"[ERROR] VM '{instance_name}' in project '{project_id}': {e}", flush=True)

        # 2. Process GKE Clusters
        elif asset_type == "container.googleapis.com/Cluster":
            project_id, location, cluster_name = parts[4], parts[6], parts[8]
            cluster_path = f"projects/{project_id}/locations/{location}/clusters/{cluster_name}"
            try:
                cluster = cluster_client.get_cluster(name=cluster_path)
                for pool in cluster.node_pools:
                    tag = "DRY-RUN" if DRY_RUN else "EXECUTING"
                    print(f"[{tag}] Scaling GKE pool '{pool.name}' of cluster '{cluster_name}' in project '{project_id}' to 0", flush=True)
                    if not DRY_RUN:
                        cluster_client.set_node_pool_size(
                            request=container_v1.SetNodePoolSizeRequest(
                                name=f"{cluster_path}/nodePools/{pool.name}",
                                node_count=0
                            )
                        )
                    gke_scaled += 1
            except Exception as e:
                print(f"[SKIP] GKE cluster '{cluster_name}' in project '{project_id}': {e}", flush=True)

    print(f"=== Weekend FinOps Summary === | GCE stopped: {gce_stopped} | GKE node pools scaled: {gke_scaled}", flush=True)
    return {"status": "success", "gce_stopped": gce_stopped, "gke_pools_scaled": gke_scaled}


@functions_framework.http
def weekend_shutdown_http(request):
    """HTTP entry point for Cloud Function."""
    return execute_finops_shutdown(), 200


if __name__ == "__main__":
    execute_finops_shutdown()
