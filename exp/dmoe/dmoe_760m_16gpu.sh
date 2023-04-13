#!/bin/bash

EXP_DIR=$1

# 512 * 1k * 400k = 200b tokens.
# 512 * 1k * 200k = 100b tokens.
# 512 * 1k * 100k = 50b tokens (default).
# 512 * 1k * 20k = 10b tokens.
TRAINING_STEPS=20000
if [ -n "${2}" ]; then
    TRAINING_STEPS=$2;
fi

NUM_EXPERTS=64
if [ -n "${3}" ]; then
    NUM_EXPERTS=$3;
fi

TOP_K=1
if [ -n "${4}" ]; then
    TOP_K=$4;
fi

LOSS_WEIGHT=0.1
if [ -n "${5}" ]; then
    LOSS_WEIGHT=$5;
fi

BATCH_SIZE=8
if [ -n "${6}" ]; then
    BATCH_SIZE=$6;
fi

##
### Pre-training for dMoE 762M parameter.
##

# MoE hyperparameters.
MOE_ARGUMENTS="\
--moe-num-experts=${NUM_EXPERTS} \
--moe-loss-weight=${LOSS_WEIGHT} \
--moe-top-k=${TOP_K}"

# Distributed hyperparameters.
DISTRIBUTED_ARGUMENTS="\
--nproc_per_node 8 \
--nnodes 2 \
--node_rank 0 \
--master_addr future-hgx-2 \
--master_port 6000"

# Model hyperparameters.
MODEL_ARGUMENTS="\
--num-layers 24 \
--hidden-size 1536 \
--num-attention-heads 16 \
--seq-length 1024 \
--max-position-embeddings 1024"

# Training hyperparameters.
TRAINING_ARGUMENTS="\
--micro-batch-size ${BATCH_SIZE} \
--global-batch-size 1024 \
--train-iters ${TRAINING_STEPS} \
--lr-decay-iters ${TRAINING_STEPS} \
--lr 0.00015 \
--min-lr 0.00001 \
--lr-decay-style cosine \
--lr-warmup-fraction 0.01 \
--clip-grad 1.0 \
--init-method-std 0.01"

PILE_DATASET="\
1.0 \
/tmp/01_text_document \
1.0 \
/tmp/02_text_document \
1.0 \
/tmp/03_text_document \
1.0 \
/tmp/04_text_document \
1.0 \
/tmp/05_text_document \
1.0 \
/tmp/06_text_document \
1.0 \
/tmp/07_text_document \
1.0 \
/tmp/08_text_document \
1.0 \
/tmp/09_text_document \
1.0 \
/tmp/10_text_document \
1.0 \
/tmp/11_text_document \
1.0 \
/tmp/12_text_document \
1.0 \
/tmp/13_text_document \
1.0 \
/tmp/14_text_document \
1.0 \
/tmp/15_text_document \
1.0 \
/tmp/16_text_document \
1.0 \
/tmp/17_text_document \
1.0 \
/tmp/18_text_document \
1.0 \
/tmp/19_text_document \
1.0 \
/tmp/20_text_document \
1.0 \
/tmp/21_text_document \
1.0 \
/tmp/22_text_document \
1.0 \
/tmp/23_text_document \
1.0 \
/tmp/24_text_document \
1.0 \
/tmp/25_text_document \
1.0 \
/tmp/26_text_document \
1.0 \
/tmp/27_text_document \
1.0 \
/tmp/28_text_document \
1.0 \
/tmp/29_text_document"

# NOTE: We don't train for enough tokens for the
# split to matter.
DATA_ARGUMENTS="\
--data-path ${PILE_DATASET} \
--vocab-file ../gpt2-vocab.json \
--merge-file ../gpt2-merges.txt \
--make-vocab-size-divisible-by 1024 \
--split 969,30,1"

COMPUTE_ARGUMENTS="\
--fp16 \
--DDP-impl local \
--moe-expert-model-parallelism \
--no-async-tensor-model-parallel-allreduce \
--pipeline-model-parallel-size 2"

CHECKPOINT_ARGUMENTS="\
--save-interval 2000 \
--save ./${EXP_DIR}"

EVALUATION_ARGUMENTS="\
--eval-iters 100 \
--log-interval 100 \
--eval-interval 1000"

python -m torch.distributed.launch ${DISTRIBUTED_ARGUMENTS} \
       third_party/Megatron-LM/pretrain_gpt.py \
       ${MOE_ARGUMENTS} \
       ${MODEL_ARGUMENTS} \
       ${TRAINING_ARGUMENTS} \
       ${DATA_ARGUMENTS} \
       ${COMPUTE_ARGUMENTS} \
       ${CHECKPOINT_ARGUMENTS} \
       ${EVALUATION_ARGUMENTS} |& tee ./${EXP_DIR}/train.log
