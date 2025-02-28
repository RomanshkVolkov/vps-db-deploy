>[!IMPORTANT]
> - 1password (optional - need modify script if you don't use)
> - know how to read
> - change type volume for production from "bind mount" to "named volume"

```
Example usage:
./deploy.sh -i <mysql|sqlserver|mariadb|postgres|mongo> -t <target> -p <port-expose-container> -s <op_password_reference> -e <enviroment>
```
