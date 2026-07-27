#!/usr/bin/env python3
"""Gera seed-prompt.sql a partir dos .md-fonte de 00-nucleo/.

Uso:  python3 30-integracoes/supabase/gerar-seed-prompt.py

O agente nao le os .md em runtime: ele le a copia em `prompt_ativo` no
Supabase. Editou um .md-fonte -> rode isto -> rode o SQL gerado no SQL Editor.
Sem esse passo, a mudanca existe no git e nao existe ao vivo.

Versionado: desativa a versao ativa anterior e insere a nova como ativa. Nada
e apagado, o rollback fica preservado.
"""
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parents[2]
NUCLEO = RAIZ / "00-nucleo"
SAIDA = RAIZ / "30-integracoes/supabase/seed-prompt.sql"

# chave em prompt_ativo -> arquivo fonte
CHAVES = {
    "objetivo": "objetivo.md",
    "compliance": "compliance-e-etica.md",
    "objecoes": "objecoes.md",
}

CABECALHO = """-- Sincroniza prompt_ativo com os .md-fonte de 00-nucleo/.
-- GERADO AUTOMATICAMENTE por 30-integracoes/supabase/gerar-seed-prompt.py
-- NAO EDITE A MAO: edite o .md e rode o gerador de novo.
--
-- Cobre as tres chaves que o agente carrega em runtime: objetivo, compliance
-- e objecoes. Rodar de novo cria uma nova versao ativa de todas, mesmo que
-- alguma nao tenha mudado -- o rollback preserva as anteriores, entao e
-- seguro; so gera um bump de versao a mais.
--
-- Cole inteiro no SQL Editor do Supabase e rode.

begin;
"""

BLOCO = """
-- {chave}  (fonte: 00-nucleo/{arquivo}, {linhas} linhas)
update prompt_ativo set ativo = false where chave = '{chave}' and ativo;
insert into prompt_ativo (chave, versao, conteudo, ativo)
values ('{chave}',
        coalesce((select max(versao) from prompt_ativo where chave = '{chave}'), 0) + 1,
        {tag}{conteudo}{tag},
        true);
"""

RODAPE = """
commit;

-- Conferencia: as tres chaves ativas, com a versao nova.
-- select chave, versao, length(conteudo) as chars, ativo
-- from prompt_ativo where ativo order by chave;
"""


def tag_segura(texto: str) -> str:
    """Escolhe um dollar-quote que nao colida com o conteudo."""
    for candidato in ("$conteudo$", "$md$", "$prompt$", "$q1$", "$q2$"):
        if candidato not in texto:
            return candidato
    raise SystemExit("nenhum dollar-quote seguro para o conteudo")


def main() -> int:
    partes = [CABECALHO]
    for chave, arquivo in CHAVES.items():
        caminho = NUCLEO / arquivo
        if not caminho.exists():
            raise SystemExit(f"fonte nao encontrada: {caminho}")
        conteudo = caminho.read_text(encoding="utf-8")
        partes.append(BLOCO.format(
            chave=chave,
            arquivo=arquivo,
            linhas=conteudo.count("\n") + 1,
            tag=tag_segura(conteudo),
            conteudo=conteudo,
        ))
    partes.append(RODAPE)
    SAIDA.write_text("".join(partes), encoding="utf-8")

    print(f"gerado: {SAIDA.relative_to(RAIZ)}")
    for chave, arquivo in CHAVES.items():
        n = len((NUCLEO / arquivo).read_text(encoding="utf-8"))
        print(f"  {chave:11s} <- {arquivo:24s} {n:6d} chars")
    return 0


if __name__ == "__main__":
    sys.exit(main())
