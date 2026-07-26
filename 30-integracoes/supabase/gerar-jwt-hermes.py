#!/usr/bin/env python3
"""Gera o JWT que o Hermes usa no lugar da service_role key.

    export SUPABASE_JWT_SECRET='<JWT Secret do projeto>'
    python3 30-integracoes/supabase/gerar-jwt-hermes.py

Rode `role-hermes.sql` antes -- o token só serve se o role existir.

Por que um script local e não o jwt.io: para assinar o token lá você cola o
JWT Secret do projeto num site de terceiro. Esse segredo assina QUALQUER role,
inclusive `service_role` -- quem o tiver tem o banco inteiro. Só stdlib aqui,
nada sai da máquina.
"""

import argparse
import base64
import hashlib
import hmac
import json
import os
import sys
import time


def b64url(dados: bytes) -> str:
    """Base64 sem padding, como o JWT exige."""
    return base64.urlsafe_b64encode(dados).rstrip(b"=").decode()


def gerar_jwt(segredo: str, role: str, dias: int) -> str:
    agora = int(time.time())
    cabecalho = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "role": role,      # o PostgREST faz SET ROLE com base nisto
        "iss": "supabase",
        "iat": agora,
        "exp": agora + dias * 86400,
    }

    assinar = f"{b64url(json.dumps(cabecalho, separators=(',', ':')).encode())}." \
              f"{b64url(json.dumps(payload, separators=(',', ':')).encode())}"
    assinatura = hmac.new(segredo.encode(), assinar.encode(), hashlib.sha256).digest()
    return f"{assinar}.{b64url(assinatura)}"


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--role", default="hermes_agent", help="role Postgres (padrão: hermes_agent)")
    p.add_argument("--dias", type=int, default=365, help="validade em dias (padrão: 365)")
    args = p.parse_args()

    segredo = os.environ.get("SUPABASE_JWT_SECRET")
    if not segredo:
        sys.exit(
            "Faltou SUPABASE_JWT_SECRET.\n"
            "Pegue em: Supabase → Settings → API → JWT Settings → JWT Secret\n"
            "Depois: export SUPABASE_JWT_SECRET='...'\n\n"
            "Passe por variável de ambiente, não como argumento — argumento fica "
            "no histórico do shell e aparece pra qualquer processo via `ps`."
        )

    token = gerar_jwt(segredo, args.role, args.dias)

    venc = time.strftime("%Y-%m-%d", time.localtime(time.time() + args.dias * 86400))
    print(f"# role={args.role}  vence em {venc}", file=sys.stderr)
    print(f"# Anote a data: quando vencer, o Hermes para de gravar sugestões "
          f"silenciosamente.", file=sys.stderr)
    print(token)


if __name__ == "__main__":
    main()
