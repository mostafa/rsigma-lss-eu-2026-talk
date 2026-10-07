# Rule provenance

The four detection rules under `base/` are copied without modification from SigmaHQ commit `994da16651194500b607a3007186c29779e1f961`.

- `lnx_auditd_user_discovery.yml`: `rules/linux/auditd/execve/lnx_auditd_user_discovery.yml`
- `lnx_auditd_file_or_folder_permissions.yml`: `rules/linux/auditd/execve/lnx_auditd_file_or_folder_permissions.yml`
- `proc_creation_lnx_curl_usage.yml`: `rules/linux/process_creation/proc_creation_lnx_curl_usage.yml`
- `proc_creation_lnx_network_scanning_tools.yml`: `rules/linux/process_creation/proc_creation_lnx_susp_network_utilities_execution.yml`

`correlation.yml` is authored for this demonstration. It references the four upstream rule IDs in the order used by the attack sequence.
