import os
import logging
from google.cloud import asset_v1, compute_v1, container_v1
import functions_framework

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

FOLDER_ID = os.environ.get("FOLDER_ID")
DRY_RUN = os.environ.get("DRY_RUN", "false").lower() in ("true", "1", "yes")


def execute_finops_shutdown():
    """Discover and stop all GCE instances and scale down GKE clusters in a single pass."""
    if not FOLDER_ID:
        raise ValueError("Environment variable 'FOLDER_ID' is required but not set.")

    parent_scope = f"folders/{FOLDER_ID}"
    logger.info(f"Starting Weekend FinOps shutdown | Scope: {parent_scope} | DRY_RUN: {DRY_RUN}")

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
                    action = "DRY-RUN Simulation" if DRY_RUN else "EXECUTING"
                    logger.info(f"[{action}] Stopping VM '{instance_name}' in project '{project_id}' (Zone: {zone})")
                    if not DRY_RUN:
                        instances_client.stop(project=project_id, zone=zone, instance=instance_name)
                    gce_stopped += 1
                else:
                    logger.info(f"[GCE] VM '{instance_name}' in project '{project_id}' is already {instance.status}")
            except Exception as e:
                logger.error(f"[GCE] Error processing VM '{instance_name}' ({project_id}): {e}")

        # 2. Process GKE Clusters
        elif asset_type == "container.googleapis.com/Cluster":
            project_id, location, cluster_name = parts[4], parts[6], parts[8]
            cluster_path = f"projects/{project_id}/locations/{location}/clusters/{cluster_name}"
            try:
                cluster = cluster_client.get_cluster(name=cluster_path)
                for pool in cluster.node_pools:
                    action = "DRY-RUN Simulation" if DRY_RUN else "EXECUTING"
                    logger.info(f"[{action}] Scaling node pool '{pool.name}' of cluster '{cluster_name}' in project '{project_id}' to 0 nodes")
                    if not DRY_RUN:
                        cluster_client.set_node_pool_size(
                            request=container_v1.SetNodePoolSizeRequest(
                                name=f"{cluster_path}/nodePools/{pool.name}",
                                node_count=0
                            )
                        )
                    gke_scaled += 1
            except Exception as e:
                logger.warning(f"[GKE] Cluster '{cluster_name}' in project '{project_id}': {e}")

    logger.info(f"Weekend FinOps completed | GCE stopped: {gce_stopped} | GKE pools scaled to 0: {gke_scaled}")
    return {"status": "success", "gce_stopped": gce_stopped, "gke_pools_scaled": gke_scaled}


@functions_framework.http
def weekend_shutdown_http(request):
    """HTTP entry point for Cloud Function."""
    return execute_finops_shutdown(), 200


if __name__ == "__main__":
    execute_finops_shutdown()
