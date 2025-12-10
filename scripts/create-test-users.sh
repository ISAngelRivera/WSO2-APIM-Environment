#!/bin/bash
# =============================================================================
# Script para crear usuarios de prueba en WSO2 APIM
# =============================================================================
# Crea usuarios dev1 y dev2 con rol Internal/creator para probar que el
# sistema captura correctamente el usuario que hace clic en "Registrar en UAT"
#
# Uso: ./scripts/create-test-users.sh
# =============================================================================

set -e

echo "=============================================="
echo "  Creando usuarios de prueba para APIOps"
echo "=============================================="

WSO2_HOST="${WSO2_HOST:-localhost}"
WSO2_PORT="${WSO2_PORT:-9443}"

# Función para verificar si usuario existe via SOAP
user_exists() {
  local username=$1
  local response=$(curl -sk -X POST \
    -H "Content-Type: text/xml;charset=UTF-8" \
    -H "SOAPAction: urn:isExistingUser" \
    -u admin:admin \
    -d '<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ser="http://service.ws.um.carbon.wso2.org">
   <soapenv:Header/>
   <soapenv:Body>
      <ser:isExistingUser>
         <ser:userName>'"$username"'</ser:userName>
      </ser:isExistingUser>
   </soapenv:Body>
</soapenv:Envelope>' \
    "https://${WSO2_HOST}:${WSO2_PORT}/services/RemoteUserStoreManagerService" 2>/dev/null)

  echo "$response" | grep -q ">true<"
}

# Función para crear usuario via SOAP (RemoteUserStoreManagerService)
create_user() {
  local username=$1
  local password=$2
  local firstname=$3
  local lastname=$4
  local email=$5

  echo ""
  echo "Creando usuario: $username..."

  # Verificar si ya existe
  if user_exists "$username"; then
    echo "  Usuario $username ya existe, saltando..."
    return 0
  fi

  # Crear usuario via SOAP RemoteUserStoreManagerService
  local response=$(curl -sk -X POST \
    -H "Content-Type: text/xml;charset=UTF-8" \
    -H "SOAPAction: urn:addUser" \
    -u admin:admin \
    -d '<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ser="http://service.ws.um.carbon.wso2.org" xmlns:xsd="http://common.mgt.user.carbon.wso2.org/xsd">
   <soapenv:Header/>
   <soapenv:Body>
      <ser:addUser>
         <ser:userName>'"$username"'</ser:userName>
         <ser:credential>'"$password"'</ser:credential>
         <ser:roleList>Internal/creator</ser:roleList>
         <ser:roleList>Internal/publisher</ser:roleList>
         <ser:claims>
            <xsd:claimURI>http://wso2.org/claims/givenname</xsd:claimURI>
            <xsd:value>'"$firstname"'</xsd:value>
         </ser:claims>
         <ser:claims>
            <xsd:claimURI>http://wso2.org/claims/lastname</xsd:claimURI>
            <xsd:value>'"$lastname"'</xsd:value>
         </ser:claims>
         <ser:claims>
            <xsd:claimURI>http://wso2.org/claims/emailaddress</xsd:claimURI>
            <xsd:value>'"$email"'</xsd:value>
         </ser:claims>
         <ser:profileName>default</ser:profileName>
         <ser:requirePasswordChange>false</ser:requirePasswordChange>
      </ser:addUser>
   </soapenv:Body>
</soapenv:Envelope>' \
    "https://${WSO2_HOST}:${WSO2_PORT}/services/RemoteUserStoreManagerService" 2>/dev/null)

  # Verificar si hubo error
  if echo "$response" | grep -q "Fault"; then
    local error=$(echo "$response" | grep -oP '(?<=<faultstring>)[^<]+')
    echo "  ERROR: $error"
    return 1
  fi

  # Verificar que se creó
  if user_exists "$username"; then
    echo "  Creado correctamente"
    echo "  Roles asignados: Internal/creator, Internal/publisher"
    return 0
  else
    echo "  ERROR: Usuario no se creó"
    return 1
  fi
}

echo ""
echo "=============================================="
echo "  Creando usuarios de desarrollo"
echo "=============================================="

# Crear dev1 y dev2 con password simple para pruebas
# Password debe tener: mayúscula, minúscula, número y símbolo
create_user "dev1" "Dev1pass!" "Developer" "One" "dev1@test.local"
create_user "dev2" "Dev2pass!" "Developer" "Two" "dev2@test.local"

echo ""
echo "=============================================="
echo "  Verificando usuarios creados"
echo "=============================================="

printf "%-15s %-20s\n" "USUARIO" "ESTADO"
echo "----------------------------------------------"

for user in admin dev1 dev2; do
  if user_exists "$user"; then
    printf "%-15s %-20s\n" "$user" "OK"
  else
    printf "%-15s %-20s\n" "$user" "NO EXISTE"
  fi
done

echo ""
echo "=============================================="
echo "  Usuarios de prueba listos!"
echo "=============================================="
echo ""
echo "  Credenciales:"
echo "  - admin / admin (administrador)"
echo "  - dev1  / Dev1pass! (desarrollador 1)"
echo "  - dev2  / Dev2pass! (desarrollador 2)"
echo ""
echo "  Todos pueden acceder al Publisher:"
echo "  https://localhost:9443/publisher"
echo ""
