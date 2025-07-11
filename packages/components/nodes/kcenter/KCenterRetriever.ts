import { BaseRetriever, BaseRetrieverInput } from '@langchain/core/retrievers'
import { INode, INodeData, INodeParams, INodeOutputsValue } from '../../src/Interface'
import { Document } from '@langchain/core/documents'
import axios from 'axios'
import { getCredentialData, getCredentialParam, handleEscapeCharacters, ICommonObject } from '../../src'

class KCenter_Retrievers implements INode {
    label: string
    name: string
    version: number
    description: string

    type: string
    icon: string
    category: string
    baseClasses: string[]

    inputs: INodeParams[]
    credential: INodeParams
    outputs: INodeOutputsValue[]

    tags: string[]

    constructor() {
        this.label = 'KAI Retriever'
        this.name = 'kaiRetriever'
        this.version = 1.1
        this.type = 'KAI Vector Store Retriever'
        this.icon = 'logo.svg'
        this.category = 'KCenter'
        this.description = 'Return results from KAI VectoreStore'
        this.tags = ['Utilities']
        this.baseClasses = [this.type, 'BaseRetriever']
        this.credential = {
            label: 'KAI Credential',
            name: 'credential',
            type: 'credential',
            credentialNames: ['kcenterVsApi'],
            optional: true
        }
        this.inputs = [
            {
                label: 'KAI KnowledgeBase',
                name: 'collectionName',
                type: 'string',
                placeholder: 'my_collection'
            },
            {
                label: 'Query',
                name: 'query',
                type: 'string',
                description: 'Query to retrieve documents from retriever. If not specified, user question will be used',
                optional: true,
                acceptVariable: true
            },
            {
                label: 'Language',
                name: 'language',
                type: 'string',
                description: 'Language to use',
                optional: true,
                acceptVariable: true
            },
            {
                label: 'Top K',
                name: 'topK',
                description: 'Number of top results to fetch. Default to vector store topK',
                placeholder: '1',
                type: 'number',
                optional: true,
                acceptVariable: true
            },
            {
                label: 'Result Format',
                name: 'resultFormat',
                description: 'How should the result be returned? In segments/chunks or in documents ? Default is Segments.',
                type: 'options',
                options: [
                    {
                        label: 'Segments',
                        name: 'seg',
                        description: 'Use this to get a list of segments/chunks back'
                    },
                    {
                        label: 'Documents',
                        name: 'doc',
                        description: 'Use this to get a list of documents back.'
                    }
                ],
                default: 'seg',
                optional: true,
                acceptVariable: true
            }
        ]
        this.outputs = [
            {
                label: 'Retriever',
                name: 'retriever',
                baseClasses: this.baseClasses
            },
            {
                label: 'Document',
                name: 'document',
                description: 'Array of segment/document objects containing metadata and content',
                baseClasses: ['Document', 'json']
            },
            {
                label: 'Text',
                name: 'text',
                description: 'Concatenated string from content of documents',
                baseClasses: ['string', 'json']
            }
        ]
    }

    async init(nodeData: INodeData, input: string, options: ICommonObject): Promise<any> {
        const DEFAULT_TOP_K: number = 1
        const DEFAULT_RESULT_FORMAT: string = 'seg'

        if (process.env.DEBUG === 'true') console.info('Input data: ', nodeData.inputs)

        //const connectionString = nodeData.inputs?.connectionString as string
        //const apiKey = nodeData.inputs?.apiKey as string
        const credentialData = await getCredentialData(nodeData.credential ?? '', options)
        const connectionString = getCredentialParam('baseUrl', credentialData, nodeData)
        const apiKey = getCredentialParam('apiKey', credentialData, nodeData)

        const collectionName = nodeData.inputs?.collectionName as string
        const language = nodeData.inputs?.language as string
        const query = nodeData.inputs?.query as string

        const resultFormat = nodeData.inputs?.resultFormat as string

        const topK = nodeData.inputs?.topK as string
        const k = topK ? parseInt(topK, 10) : DEFAULT_TOP_K
        const output = nodeData.outputs?.output as string

        const retrieverConfig = {
            knowledgeBaseId: collectionName,
            url: connectionString,
            apiKey: apiKey,
            languages: language ? [language] : [],
            topK: k ?? DEFAULT_TOP_K,
            resultFormat: resultFormat ?? DEFAULT_RESULT_FORMAT
        } as KCenterRetrieverRetrieverArgs

        if (process.env.DEBUG === 'true') console.info('RetrieverConfig: ', retrieverConfig)

        const retriever = new KCenterRetriever(retrieverConfig)

        if (output === 'retriever') return retriever
        else if (output === 'document') return await retriever._getRelevantDocuments(query ? query : input)
        else if (output === 'text') {
            let finaltext = ''

            const docs = await retriever._getRelevantDocuments(query ? query : input)

            for (const doc of docs) finaltext += `${doc.pageContent}\n`

            return handleEscapeCharacters(finaltext, false)
        }

        throw new Error(`Unknown output type '${output}'`)
    }
}

export interface KCenterRetrieverRetrieverArgs {
    url: string
    knowledgeBaseId: string
    apiKey: string
    languages: string[]
    topK: number
    resultFormat: string
}

class KCenterRetriever extends BaseRetriever {
    lc_namespace = ['langchain', 'retrievers']

    config: KCenterRetrieverRetrieverArgs

    constructor(input: KCenterRetrieverRetrieverArgs) {
        super({ verbose: false } as BaseRetrieverInput)

        this.config = input
    }

    async _getRelevantDocuments(query: string): Promise<Document[]> {
        let documents: Document[] = []

        const requestConfig = {
            headers: {
                'X-API-KEY': `${this.config.apiKey}`,
                'Content-Type': 'application/json',
                Accept: 'application/json'
            }
        }

        const baseUrl = this.config.url.endsWith('/') ? this.config.url.slice(0, -1) : this.config.url
        const encodedKbaseId = encodeURIComponent(this.config.knowledgeBaseId)
        const url = `${baseUrl}/api/v1/knowledgebases/${encodedKbaseId}/search`

        const requestBody = {
            query: query,
            lang: this.config.languages ?? [],
            limit: this.config.topK ?? 1,
            layout: this.config.resultFormat ?? ''
        }

        try {
            if (process.env.DEBUG === 'true') console.info(`Send search request to URL ${url}: `, requestBody)

            let returnedDocs = await axios.post(url, requestBody, requestConfig)

            const finalResults: Document<Record<string, any>>[] = []

            returnedDocs.data.results.forEach((result: any) => {
                const doc = new Document({
                    id: result.id,
                    pageContent: result.text,
                    metadata: {
                        relevance_score: result.score,
                        guid: result.meta?.docref?.guid || result.meta?.guid,
                        lang: result.meta?.docref?.lang || result.meta?.lang,
                        title: result.meta?.docref?.title || result.meta?.title,
                        url: result.meta?.docref?.url || result.meta?.url
                    }
                })

                finalResults.push(doc)
            })

            const spliceResults = finalResults.splice(0, this.config.topK)

            if (process.env.DEBUG === 'true') console.info('Final result set: ', spliceResults)

            return spliceResults
        } catch (error) {
            return documents
        }
    }
}

module.exports = { nodeClass: KCenter_Retrievers }
